#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('All','Prepare','Build','Validate','Serve')][string]$Stage='All',
    [ValidateSet('local','preview','production')][string]$Target='local',
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$Version='0.0.0-local'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$platformRoot=Split-Path $PSScriptRoot -Parent
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module "$platformRoot/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$platformRoot/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$'){throw 'Guide-site evidence must use a named directory under .processing.'}
$output=Resolve-GuideWorkspacePath $root $OutputPath
$policy=Import-GuidePolicy (Resolve-GuideWorkspacePath $root $PolicyPath)
$source=Resolve-GuideWorkspacePath $root $policy.wrapper.sourcePath
$commit=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot resolve guide-site source commit.'}
$site=Join-Path $output 'site'
$overlay=Join-Path $output 'candidate-platform.json'
$configs=@('hugo.yaml',"hugo.$Target.yaml",$overlay)
if($Stage -in @('All','Prepare','Serve')){
    if(Test-Path -LiteralPath $output){throw 'Guide-site output exists; choose a fresh evidence directory.'}
    [IO.Directory]::CreateDirectory($output)|Out-Null
    $module=Join-Path $platformRoot 'system/OpenGuidePlatform.Hugo.Guides'
    # Bind the consumer to the packaged candidate without changing its module or source files.
    $values=@{module=@{replacements=@("github.com/nkdAgility/HugoGuides/module -> $($module.Replace('\','/'))")};params=@{AzureSitesConfig=$Target;GitVersion_SemVer="v$Version"}}
    [IO.File]::WriteAllText($overlay,($values|ConvertTo-Json -Depth 10))
    $null=Get-GuideHugoToolchain
    & "$PSScriptRoot/Prepare-GuideSite.ps1" -WorkspaceRoot $root -PolicyPath (Join-Path $root $PolicyPath) -SourceCommit $commit -OutputPath "$OutputPath/prepare" -Target $Target -PlatformVersion $Version -ConfigFiles $configs -ProductionConfigFiles @('hugo.yaml','hugo.production.yaml',$overlay)
}
if($Stage -in @('All','Build','Validate')){
    $assessment=Get-Content "$output/prepare/assessment.json" -Raw|ConvertFrom-Json
    if($assessment.outcome -ne 'pass' -or $assessment.sourceCommit -cne $commit -or $assessment.target -cne $Target -or $assessment.policyDigest -cne (Get-FileHash (Join-Path $root $PolicyPath)).Hash.ToLowerInvariant()){throw 'Build requires passing Prepare evidence for this source, policy and target.'}
}
if($Stage -in @('All','Build')){
    if(Test-Path -LiteralPath $site){throw 'Site output already exists.'}
    $previousResources=$env:HUGO_RESOURCEDIR
    try{
        $env:HUGO_RESOURCEDIR=Join-Path $output 'resources'
        $lines=@(& hugo --source $source --config ($configs -join ',') --destination $site --environment $Target --printPathWarnings 2>&1)
        $exit=$LASTEXITCODE
        [IO.File]::WriteAllLines("$output/hugo.log",[string[]]$lines)
        $lines|ForEach-Object{Write-Host $_}
        if($exit -ne 0 -or @($lines|Where-Object { [string]$_ -match '^ERROR' }).Count){throw "Guide-site Hugo build failed ($exit)."}
    }finally{$env:HUGO_RESOURCEDIR=$previousResources}
    function Merge-Hosting($base,$overlay){foreach($key in $overlay.Keys){if($base.Contains($key) -and $base[$key] -is [Collections.IDictionary] -and $overlay[$key] -is [Collections.IDictionary]){Merge-Hosting $base[$key] $overlay[$key]}else{$base[$key]=$overlay[$key]}}}
    if(Test-Path "$root/staticwebapp.config.json"){
        $hosting=Get-Content "$root/staticwebapp.config.json" -Raw|ConvertFrom-Json -AsHashtable
        $hostingTarget=if($Target -eq 'local'){'canary'}else{$Target}
        if(Test-Path "$root/staticwebapp.config.$hostingTarget.json"){Merge-Hosting $hosting (Get-Content "$root/staticwebapp.config.$hostingTarget.json" -Raw|ConvertFrom-Json -AsHashtable)}
        [IO.File]::WriteAllText("$site/staticwebapp.config.json",($hosting|ConvertTo-Json -Depth 100))
    }
    [IO.Directory]::CreateDirectory((Join-Path $site '.well-known'))|Out-Null
    $publishedIdentity=[ordered]@{sourceCommit=$commit;platformVersion=$Version;target=$Target}
    [IO.File]::WriteAllText((Join-Path $site '.well-known/open-guide-platform.json'),($publishedIdentity|ConvertTo-Json))
    $identity=New-GuideArtifactIdentity -ArtifactRoot $site -Target $Target -SourceCommit $commit -Version $Version -SourceDirty (@(& git -C $root status --porcelain).Count -gt 0)
    [IO.File]::WriteAllText("$output/artifact-identity.json",($identity|ConvertTo-Json -Depth 100))
}
if($Stage -in @('All','Validate')){
    $forbidden=@()
    if($Target -eq 'production'){
        $forbidden=@($policy.publication.permanentExclusions|Where-Object { $_.environment -eq 'production' -and $_.subject -eq 'language' }|ForEach-Object {$_.id})
    }
    $report=Get-GuideArtifactAssessment -ArtifactRoot $site -IdentityPath "$output/artifact-identity.json" -HugoLogPath "$output/hugo.log" -SourceCommit $commit -Target $Target -RequiredRoutes $policy.wrapper.requiredRoutes -ForbiddenPaths $forbidden
    [IO.File]::WriteAllText("$output/artifact-validation.json",($report|ConvertTo-Json -Depth 100))
    & "$PSScriptRoot/Write-GuideSiteValidationSummary.ps1" -OutputPath $output
    if($report.Outcome -ne 'pass'){throw "Guide-site validation $($report.Outcome). See $output/artifact-validation.json"}
}

if($Stage -eq 'Serve'){
    & hugo serve --source $source --config ($configs -join ',') --destination $site --environment $Target
    if($LASTEXITCODE -ne 0){throw "Hugo server exited with $LASTEXITCODE"}
}