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
Import-Module (Join-Path $root 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
$sourceCommit=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot determine the build source commit.'}
function Merge-Config([Collections.IDictionary]$base,[Collections.IDictionary]$overlay){
    foreach($key in $overlay.Keys){if($base.Contains($key) -and $base[$key] -is [Collections.IDictionary] -and $overlay[$key] -is [Collections.IDictionary]){Merge-Config $base[$key] $overlay[$key]}else{$base[$key]=$overlay[$key]}}
}
if($Stage -in @('All','Prepare','Build')){
    $toolchain=Get-GuideHugoToolchain
    Write-Host "Hugo $($toolchain.Version) Extended verified."
}
if($Stage -in @('All','Prepare')){
    & (Join-Path $PSScriptRoot 'Test-PlatformContracts.ps1')
    & (Join-Path $PSScriptRoot 'Test-PlatformCore.ps1')

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
        $lines=@(& hugo --source (Join-Path $root 'examples/reference-guide-site') --config "hugo.yaml,hugo.$Target.yaml,$overlay" --destination $site --environment $Target --logLevel info --printPathWarnings 2>&1)
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
    $dirty=@(& git -C $root status --porcelain).Count -gt 0
    if($LASTEXITCODE -ne 0){throw 'Cannot inspect source state.'}
    $identity=New-GuideArtifactIdentity -ArtifactRoot $site -Target $Target -SourceCommit $sourceCommit -Version $Version -SourceDirty $dirty
    [IO.File]::WriteAllText((Join-Path $output 'artifact-identity.json'),($identity|ConvertTo-Json -Depth 100))
}
if($Stage -in @('All','Validate')){
    $validation=Test-GuideArtifact -ArtifactRoot $site -RequiredRoutes @('/') -RequiredDownloads @('staticwebapp.config.json') -HugoLog (Get-Content -LiteralPath (Join-Path $output 'hugo.log') -ErrorAction Stop)
    try {
        $identity=Get-Content -LiteralPath (Join-Path $output 'artifact-identity.json') -Raw|ConvertFrom-Json -ErrorAction Stop
        $null=Test-GuideArtifactIdentity -ArtifactRoot $site -Identity $identity -ExpectedTarget $Target -ExpectedSourceCommit $sourceCommit
    } catch {
        $validation.Outcome='fail'
        $validation.Findings+= [pscustomobject]@{Code='ARTIFACT_IDENTITY_INVALID';Path='artifact-identity.json';Message=$_.Exception.Message}
    }
    $report=[ordered]@{Outcome=$validation.Outcome;SourceCommit=$sourceCommit;Target=$Target;SizeBytes=$validation.SizeBytes;FileCount=$validation.Files.Count;Findings=@($validation.Findings)}
    [IO.File]::WriteAllText((Join-Path $output 'artifact-validation.json'),($report|ConvertTo-Json -Depth 100))
    if($validation.Outcome -ne 'pass'){$validation.Findings|Format-Table -AutoSize|Out-Host;throw 'Artifact validation failed; inspect artifact-validation.json.'}
    "Validated $($validation.Files.Count) files in $site. No deployment performed."
}