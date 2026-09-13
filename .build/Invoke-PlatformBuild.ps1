#Requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('All','Prepare','Build','Validate')][string]$Stage,[ValidateSet('local','preview','production','canary')][string]$Target,[string]$OutputPath,[string]$Version)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$' -or $OutputPath.Split('/') -contains '..'){throw 'Platform build output must be a named directory under .processing/.'}
$output=[IO.Path]::GetFullPath((Join-Path $root $OutputPath))
$cursor=$output
while($cursor -and $cursor.Length -ge $root.Length){if(Test-Path -LiteralPath $cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Linked build output is not supported.'}};$cursor=[IO.Path]::GetDirectoryName($cursor)}
$site=Join-Path $output 'site'
function Merge-Config([Collections.IDictionary]$base,[Collections.IDictionary]$overlay){
    foreach($key in $overlay.Keys){if($base.Contains($key) -and $base[$key] -is [Collections.IDictionary] -and $overlay[$key] -is [Collections.IDictionary]){Merge-Config $base[$key] $overlay[$key]}else{$base[$key]=$overlay[$key]}}
}
if($Stage -in @('All','Prepare')){
    & (Join-Path $PSScriptRoot 'Test-PlatformContracts.ps1')
    & (Join-Path $PSScriptRoot 'Test-PlatformCore.ps1')
    if(-not (Get-Command hugo -CommandType Application -ErrorAction SilentlyContinue)){throw 'Hugo Extended is required for the platform reference build.'}
}
if($Stage -in @('All','Build')){
    if(Test-Path -LiteralPath $output){throw 'Build output already exists; choose a new OutputPath to avoid stale artifacts.'}
    [IO.Directory]::CreateDirectory($output)|Out-Null
    # Overlay generated outside source; the fragile Hugo module files are never rewritten.
    $overlay=Join-Path $output 'build-overlay.json'
    [IO.File]::WriteAllText($overlay,(@{params=@{AzureSitesConfig=$Target;GitVersion_SemVer="v$Version"}}|ConvertTo-Json -Depth 10))
    $previousResources=$env:HUGO_RESOURCEDIR
    try {
        $env:HUGO_RESOURCEDIR=Join-Path $output 'resources'
        $lines=@(& hugo --source (Join-Path $root 'examples/reference-guide-site') --config "hugo.yaml,hugo.$Target.yaml,$overlay" --destination $site --environment $Target --logLevel info 2>&1)
        $exitCode=$LASTEXITCODE
        $lines|ForEach-Object { Write-Host $_ }
        [IO.File]::WriteAllLines((Join-Path $output 'hugo.log'),[string[]]$lines)
        if($exitCode -ne 0 -or @($lines|Where-Object { [string]$_ -match '^ERROR' }).Count){throw "Hugo failed with exit code $exitCode."}
    } finally {$env:HUGO_RESOURCEDIR=$previousResources}
    $hostingTarget=if($Target -eq 'local'){'canary'}else{$Target}
    $config=Get-Content -LiteralPath (Join-Path $root 'staticwebapp.config.json') -Raw|ConvertFrom-Json -AsHashtable
    $override=Get-Content -LiteralPath (Join-Path $root "staticwebapp.config.$hostingTarget.json") -Raw|ConvertFrom-Json -AsHashtable
    Merge-Config $config $override
    [IO.File]::WriteAllText((Join-Path $site 'staticwebapp.config.json'),($config|ConvertTo-Json -Depth 100))
}
if($Stage -in @('All','Validate')){
    if(-not [IO.File]::Exists((Join-Path $site 'index.html'))){throw 'Build artifact homepage is missing.'}
    $files=@(Get-ChildItem -LiteralPath $site -Recurse -File)
    if(($files|Measure-Object -Property Length -Sum).Sum -gt 524288000){throw 'Site artifact exceeds the 500 MB limit.'}
    foreach($file in $files){
        if($file.Extension -eq '.json'){$null=Get-Content -LiteralPath $file.FullName -Raw|ConvertFrom-Json -ErrorAction Stop}
        if($file.Extension -in @('.html','.json','.xml','.yaml','.yml')){if([IO.File]::ReadAllText($file.FullName) -match '#\{[A-Za-z0-9_.]+\}#'){throw "Unresolved build token: $($file.FullName)"}}
    }
    if(-not [IO.File]::Exists((Join-Path $site 'staticwebapp.config.json'))){throw 'Final hosting configuration is missing from the artifact.'}
    "Validated $($files.Count) files in $site. No deployment performed."
}