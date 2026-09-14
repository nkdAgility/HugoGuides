#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('All','Prepare','Build','Validate','Serve')][string]$Stage='All',
    [ValidateSet('local','canary','preview','production')][string]$Target='local',
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [string]$PolicyPath,[string]$SourcePath='site',
    [Parameter(Mandatory)][string]$OutputPath,
    $DeliveryContext,[string]$Version='0.0.0-local',[string]$SiteVersion,[string]$BaseUrl
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$platformRoot=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module "$platformRoot/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1"
Import-Module "$platformRoot/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1"
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$'){throw 'Guide-site evidence must use a named directory under .processing.'}
$output=Resolve-GuideWorkspacePath $root $OutputPath
$commit=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot resolve guide-site source commit.'}
$site=Join-Path $output 'site'
$overlay=Join-Path $output 'candidate-platform.json'
$inferred=-not $PolicyPath
if($inferred){$PolicyPath="$OutputPath/discovered-site.json"}
$configs=@('hugo.yaml',"hugo.$Target.yaml",$overlay)
if($Stage -in @('All','Prepare','Serve')){
    if(Test-Path -LiteralPath $output){throw 'Guide-site output exists; choose a fresh evidence directory.'}
    [IO.Directory]::CreateDirectory($output)|Out-Null
    try {
        $policy=if($inferred){@{wrapper=@{sourcePath=$SourcePath}}}else{Import-GuidePolicy (Resolve-GuideWorkspacePath $root $PolicyPath)}
        $source=Resolve-GuideWorkspacePath $root $policy.wrapper.sourcePath
        $inputArguments=@{WorkspaceRoot=$root;Policy=$policy;PolicyPath=$PolicyPath;PlatformRoot=$platformRoot;OverlayPath=$overlay;Version=$Version;Target=$Target}
        $resolution=Get-GuideModuleResolution -PlatformRoot $platformRoot -SourcePath $source -Version $Version
        $values=@{params=@{AzureSitesConfig=$Target;GitVersion_SemVer="v$(if($SiteVersion){$SiteVersion}else{$Version})"}}
        if($resolution.Mode -ne 'release'){$values.module=@{replacements=@($resolution.Replacements)}}
        if($BaseUrl){
            $address=[uri]$BaseUrl
            if(-not $address.IsAbsoluteUri -or $address.Scheme -notin @('http','https') -or $address.UserInfo -or $address.Query -or $address.Fragment){throw 'Site BaseUrl must be an absolute HTTP(S) URL without credentials, query or fragment.'}
            $values.baseURL=$address.AbsoluteUri
        }
        if(-not $values.ContainsKey('baseURL')){
            [IO.File]::WriteAllText($overlay,($values|ConvertTo-Json -Depth 10))
            $values.baseURL=(Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles $configs -Target $Target).Configuration.baseurl
        }
        [IO.File]::WriteAllText($overlay,($values|ConvertTo-Json -Depth 10))
        if($resolution.Mode -eq 'release'){
            $effective=(Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles $configs -Target $Target).Configuration
            if(@($effective.module.replacements|Where-Object { $_ -match '^\s*github\.com/nkdAgility/(?:HugoGuides/module|OpenGuidePlatform/system/OpenGuidePlatform\.Hugo\.Guides)\s*->' }).Count -or -not @($effective.module.imports|Where-Object { $_.path -ceq $resolution.ModulePath }).Count){throw 'Released builds require a canonical Hugo import without a configuration replacement.'}
        }
        if($inferred){
            $policy=New-GuideSiteDiscovery -WorkspaceRoot $root -SourcePath $SourcePath -ConfigFiles $configs -Target $Target -OutputPath $OutputPath
            $policy|ConvertTo-Json -Depth 100|Set-Content (Join-Path $root $PolicyPath)
            $inputArguments.Policy=$policy
        }
        $null=Get-GuideHugoToolchain
        $preparedTools=Get-GuidePreparedBuildTools
        $preparedInputs=Get-GuidePreparedInputs @inputArguments
    } catch {
        # Route setup failures through the same contract/renderers as assessment failures.
        # No assessment exists yet; never replace evidence from an earlier Prepare run.
        & "$PSScriptRoot/Prepare-GuideSite.ps1" -WorkspaceRoot $root -PolicyPath (Join-Path $root $PolicyPath) -SourceCommit $commit -OutputPath "$OutputPath/prepare" -Target $Target -PlatformVersion $Version -InputFailure $_.Exception.Message
        throw
    }
    & "$PSScriptRoot/Prepare-GuideSite.ps1" -WorkspaceRoot $root -PolicyPath (Join-Path $root $PolicyPath) -SourceCommit $commit -OutputPath "$OutputPath/prepare" -Target $Target -PlatformVersion $Version -ModulePath $resolution.ModulePath -ConfigFiles $configs -ProductionConfigFiles @('hugo.yaml','hugo.production.yaml',$overlay) -ExpectedInputs $preparedInputs -InputArguments $inputArguments
    [IO.File]::WriteAllText("$output/prepare/inputs.json",($preparedInputs|ConvertTo-Json -Depth 10))
    [IO.File]::WriteAllText("$output/prepare/tools.json",($preparedTools|ConvertTo-Json -Depth 10))
    if($DeliveryContext){$DeliveryContext|ConvertTo-Json|Set-Content "$output/delivery-context.json"}
}
if($Stage -in @('Build','Validate')){
    $policy=Import-GuidePolicy (Resolve-GuideWorkspacePath $root $PolicyPath)
    $source=Resolve-GuideWorkspacePath $root $policy.wrapper.sourcePath
    $inputArguments=@{WorkspaceRoot=$root;Policy=$policy;PolicyPath=$PolicyPath;PlatformRoot=$platformRoot;OverlayPath=$overlay;Version=$Version;Target=$Target}
}
if($Stage -in @('All','Build','Validate')){
    $assessment=Get-Content "$output/prepare/assessment.json" -Raw|ConvertFrom-Json
    $preparedInputs=Get-Content "$output/prepare/inputs.json" -Raw|ConvertFrom-Json
    Assert-GuidePreparedInputs -Expected $preparedInputs -Actual (Get-GuidePreparedInputs @inputArguments)
    if($assessment.outcome -ne 'pass' -or $assessment.sourceCommit -cne $commit -or $assessment.target -cne $Target -or $assessment.policyDigest -cne (Get-FileHash (Join-Path $root $PolicyPath)).Hash.ToLowerInvariant()){throw 'Build requires passing Prepare evidence for this source, policy and target.'}
}
if($Stage -in @('All','Build')){
    $preparedTools=Get-Content "$output/prepare/tools.json" -Raw|ConvertFrom-Json
    if($preparedTools.Sha256 -cne (Get-GuidePreparedBuildTools).Sha256){throw 'PREPARE_TOOLS_CHANGED: Build tools differ from Prepare. Run Prepare again.'}
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
    $forbidden=@(Get-GuideForbiddenPaths -Policy $policy -Target $Target)
    $requiredRoutes=@($policy.wrapper.requiredRoutes|Where-Object { $route=$_; -not @($forbidden|Where-Object {$route.StartsWith("/$_/")}).Count })
    $downloadRequirements=Get-GuideDownloadRequirements -WorkspaceRoot $root -Policy $policy -Target $Target -EnabledLanguages @($assessment.inventory.wrapper.languages)
    [IO.File]::WriteAllText("$output/download-requirements.json",($downloadRequirements|ConvertTo-Json -Depth 20))
    $report=Get-GuideArtifactAssessment -ArtifactRoot $site -IdentityPath "$output/artifact-identity.json" -HugoLogPath "$output/hugo.log" -SourceCommit $commit -Target $Target -RequiredRoutes $requiredRoutes -RequiredDownloads $downloadRequirements.RequiredPaths -ForbiddenPaths $forbidden -DownloadRequirements $downloadRequirements -AllowedLegacyDuplicates (Get-GuideLegacyAliasTargets -Policy $policy -EnabledLanguages @($assessment.inventory.wrapper.languages))
    $navigationBase=(Get-Content $overlay -Raw|ConvertFrom-Json -AsHashtable).baseURL
    $requiredContent=if($policy.wrapper.Contains('requiredPageContent')){@($policy.wrapper.requiredPageContent|Where-Object { $route=$_.route; -not @($forbidden|Where-Object {$route.StartsWith("/$_/")}).Count })}else{@()}
    $navigation=& "$PSScriptRoot/Test-GuideSiteNavigation.ps1" -ArtifactRoot $site -BaseUri $navigationBase -RequiredPageContent $requiredContent
    [IO.File]::WriteAllText("$output/navigation-validation.json",($navigation|ConvertTo-Json -Depth 10))
    $indexes=if($policy.wrapper.Contains('jsonIndexes')){@($policy.wrapper.jsonIndexes|Where-Object { $route=$_.route; -not @($forbidden|Where-Object {$route.StartsWith("/$_/")}).Count })}else{@()}
    $indexes=@($indexes|ForEach-Object {
        [pscustomobject]@{route=$_.route;requiredRoutes=@($_.requiredRoutes|Where-Object {$route=$_; -not @($forbidden|Where-Object {$route.StartsWith("/$_/")}).Count})}
    })
    $jsonReport=Test-GuideJsonIndexes -ArtifactRoot $site -BaseUri $navigationBase -Indexes $indexes -EnabledLanguages @($assessment.inventory.wrapper.languages) -ForbiddenPaths $forbidden
    [IO.File]::WriteAllText("$output/json-index-validation.json",($jsonReport|ConvertTo-Json -Depth 10))
    if($jsonReport.Outcome -ne 'pass'){$report.Outcome='fail';$report.Findings+=@($jsonReport.Findings)}
    $runtimeAnchors=if($inferred){@($navigation.Findings|Where-Object Code -eq 'INTERNAL_ANCHOR_MISSING'|ForEach-Object {@{route=('/'+$_.TargetPage);fragment=$_.Fragment}}|Sort-Object { $_.route+ '#'+$_.fragment } -Unique)}elseif($policy.wrapper.Contains('runtimeAnchors')){@($policy.wrapper.runtimeAnchors|Where-Object { $route=$_.route; -not @($forbidden|Where-Object {$route.StartsWith("/$_/")}).Count })}else{@()}
    try{
        $runtime=Test-GuideRuntimeAnchors -WorkspaceRoot $root -ArtifactRoot $site -BaseUri $navigationBase -IdentityPath "$output/artifact-identity.json" -OutputPath "$OutputPath/runtime" -Anchors $runtimeAnchors
        $navigation=Resolve-GuideRuntimeNavigation -Navigation $navigation -Runtime $runtime
        if($runtime.outcome -eq 'fail'){
            $report.Outcome='fail'
            $report.Findings+=@($runtime.observations|Where-Object {-not $_.exists}|ForEach-Object {[pscustomobject]@{Code='RUNTIME_ANCHOR_MISSING';Path=$_.route;Message="Repair declared runtime anchor #$($_.fragment): $($_.error)"}})
        }
    }catch{
        $runtime=@{schemaVersion=1;outcome='blocked';error=$_.Exception.Message;observations=@()}
        $report.Outcome='fail'
        $report.Findings+=[pscustomobject]@{Code='RUNTIME_ANCHOR_CHECK_BLOCKED';Path='runtime';Message=$_.Exception.Message}
    }
    [IO.File]::WriteAllText("$output/runtime-anchor-validation.json",($runtime|ConvertTo-Json -Depth 10))
    $navigation.Outcome=if($navigation.Findings.Count){'fail'}else{'pass'}
    if($navigation.Outcome -ne 'pass'){
        $report.Outcome='fail'
        $report.Findings+=@($navigation.Findings|ForEach-Object {[pscustomobject]@{Code=$_.Code;Path=$_.Page;Message="Repair local target $($_.Target)"}})
    }
    [IO.File]::WriteAllText("$output/artifact-validation.json",($report|ConvertTo-Json -Depth 100))
    & "$PSScriptRoot/Write-GuideSiteValidationSummary.ps1" -OutputPath $output
    if($report.Outcome -ne 'pass'){throw "Guide-site validation $($report.Outcome). See $output/artifact-validation.json"}
}

if($Stage -eq 'Serve'){
    & hugo serve --source $source --config ($configs -join ',') --destination $site --environment $Target
    if($LASTEXITCODE -ne 0){throw "Hugo server exited with $LASTEXITCODE"}
}
