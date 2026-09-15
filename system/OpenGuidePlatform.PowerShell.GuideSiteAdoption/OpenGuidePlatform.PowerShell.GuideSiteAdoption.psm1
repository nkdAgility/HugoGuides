#Requires -Version 7.4
function Invoke-GuideSiteAdoption {
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$PackageRoot,[string]$WorkspaceRoot=$PWD,[string]$SourcePath='site',[switch]$Install,[switch]$Update)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
$package=[IO.Path]::GetFullPath($PackageRoot)
$manifest=Get-Content "$package/release-manifest.json" -Raw|ConvertFrom-Json -AsHashtable
$ReleaseTag='v'+$manifest.version
$Channel=$manifest.channel
$metadata=& "$PSScriptRoot/Confirm-PlatformPackage.ps1" -PackageRoot $package -Manifest $manifest
$work=Join-Path $package ('adoption-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work)|Out-Null
function Resolve-InstallPath([string]$Relative) {
    if($Relative -match '(^/|\\|:|(^|/)\.\.(/|$))' -or [string]::IsNullOrWhiteSpace($Relative)){throw "Unsafe installation path: $Relative"}
    $path=[IO.Path]::GetFullPath((Join-Path $root $Relative))
    $cursor=$path
    while($cursor){
        if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            $item=Get-Item -LiteralPath $cursor -Force
            if($cursor -cne $path -or $Relative -notin @('AGENTS.md','CLAUDE.md') -or $item.LinkTarget.Replace('\','/') -cne '.agents/agents.md'){throw "Linked installation path: $Relative"}
        }
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    return $path
}
function Get-Digest([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Invoke-GitHub([string[]]$Arguments) {
    $value=& gh @Arguments
    if($LASTEXITCODE -ne 0){throw "GitHub operation failed: $($Arguments[0])"}
    return $value
}
 $lockPath=Resolve-InstallPath '.OpenGuidePlatform/installation.json'
$legacyLockPath=Resolve-InstallPath 'open-guide-platform.installation.json'
$previousPath=if(Test-Path $lockPath){$lockPath}else{$legacyLockPath}
$previous=if(Test-Path -LiteralPath $previousPath){Get-Content -LiteralPath $previousPath -Raw|ConvertFrom-Json -AsHashtable}else{$null}
$automatic=-not ($Install -or $Update)
if($automatic){
    if($previous){$Update=$true}else{$Install=$true}
}
if($previous -and ($previous.kind -cne 'preview-installation' -or $previous.schemaVersion -ne 1)){throw 'Unsupported installation record.'}
if($Update){if(-not $previous){throw 'No installation found; run -Install first.'}}
if($Install -and $previous){throw 'Already installed; use -Update.'}
Import-Module "$PSScriptRoot/PlatformSettings.psm1" -Force
$settingsPlan=New-GuideSettingsPlan -WorkspaceRoot $root -PackageRoot $package -SourcePath $SourcePath -Previous $previous -Manifest $manifest
$SourcePath=[string]$settingsPlan.Settings.site.source
$reviewBranch=$null
if($true){
    $branch=(& git -C $root branch --show-current).Trim()
    if($automatic -and $branch -in @('main','master')){
        $reviewBranch='codex/platform-adoption-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    }
    if($LASTEXITCODE -ne 0 -or -not $branch -or ($branch -in @('main','master') -and -not $reviewBranch)){throw 'Install/update requires a checked-out review branch, not main/master or detached HEAD.'}
    $sourceDirectory=Resolve-InstallPath $SourcePath
    if(-not (Test-Path (Join-Path $sourceDirectory 'hugo.yaml'))){throw "Hugo source not found at $SourcePath. Supply -SourcePath with the site's Hugo directory."}
}
foreach($required in @('system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/build.ps1','system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/main.yaml')){
    if(-not (Test-Path -LiteralPath "$package/$required" -PathType Leaf)){throw 'This release predates guide-site installation support; choose a newer release.'}
}
if(-not $metadata.PSObject.Properties['nativeHugoModule'] -or -not $manifest.ContainsKey('nativeHugoModule')){throw 'This release predates coordinated native Hugo installation.'}
$native=$manifest.nativeHugoModule
if($native.path -cne $metadata.nativeHugoModule.path -or $native.version -cne ('v'+$manifest.version) -or $native.version -cne $metadata.nativeHugoModule.version -or $native.sourceCommit -cne $manifest.sourceCommit -or $native.sourceCommit -cne $metadata.nativeHugoModule.sourceCommit){throw 'Native Hugo package and release identities disagree.'}
$nativeArguments=@{WorkspaceRoot=$root;SourcePath=$SourcePath;NativeModule=$native}
if($previous -and $previous.ContainsKey('nativeHugoModule')){$nativeArguments.PreviousVersion=$previous.nativeHugoModule.version}
$nativePlan=& "$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/New-NativeHugoUpdate.ps1" @nativeArguments
. "$PSScriptRoot/../OpenGuidePlatform.PowerShell.GuideSiteBuild/Versioning/GitVersion.ps1"
$versionFile='.github/GitVersion.yml'
$versionPath=Resolve-InstallPath $versionFile
$versionHash=if(Test-Path $versionPath){Get-Digest $versionPath}else{$null}
$versionFiles=@{}
if($versionHash){
    $versionOriginal=[IO.File]::ReadAllText($versionPath)
    $versionUpdated=Add-GuideGitVersionMessageDefaults -Text (ConvertTo-GuideGitVersion6Configuration -Text $versionOriginal)
    if($versionOriginal -cne $versionUpdated){$versionFiles[$versionFile]=[Text.Encoding]::UTF8.GetBytes($versionUpdated)}
}
$files=[ordered]@{}
foreach($name in $versionFiles.Keys){$files[$name]=$versionFiles[$name]}
foreach($name in $settingsPlan.Files.Keys){$files[$name]=$settingsPlan.Files[$name]}
$files['build.ps1']=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/build.ps1")
$files['.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1']=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1")
$workflow=[IO.File]::ReadAllText("$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/main.yaml")
$workflow=$workflow.Replace('__RELEASE__',$settingsPlan.WorkflowReference).Replace('__COMMIT__',$manifest.sourceCommit).Replace('__SOURCE__',($SourcePath|ConvertTo-Json -Compress))
Import-Module "$PSScriptRoot/WorkflowCallers.psm1" -Force
$callerPlan=New-GuideWorkflowCallerPlan -WorkspaceRoot $root -ReleaseTag $settingsPlan.WorkflowReference -Previous $previous -Starter $workflow
foreach($name in $callerPlan.Files.Keys){$files[$name]=$callerPlan.Files[$name]}
$actionsLockPath=Resolve-InstallPath '.github/workflows/actions.lock'
$actionsLockBefore=if(Test-Path $actionsLockPath){Get-Digest $actionsLockPath}else{$null}
foreach($item in Get-ChildItem "$package/system/OpenGuidePlatform.Agents.Integration/skills" -File -Recurse){
    $relative=[IO.Path]::GetRelativePath("$package/system/OpenGuidePlatform.Agents.Integration/skills",$item.FullName).Replace('\','/')
    $files[".agents/skills/$relative"]=[IO.File]::ReadAllBytes($item.FullName)
}
$instructions=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.Agents.Integration/instructions/guide-site.md")
$files['.agents/agents.md']=$instructions
$files['AGENTS.md']=$instructions
$files['CLAUDE.md']=$instructions
# Fail before any tracked changes if this machine cannot create Git-compatible shims.
try{New-Item -ItemType SymbolicLink -Path (Join-Path $work 'shim-test') -Target '.agents/agents.md' -WhatIf:$false | Out-Null}
catch{throw "Symbolic links are required. Enable Windows Developer Mode (or use an elevated shell), run git config --global core.symlinks true before cloning. Technical detail: $($_.Exception.Message)"}
$files['.github/copilot-instructions.md']=$instructions
# Native dependency/configuration patches remain consumer-owned.
foreach($name in $nativePlan.Files.Keys){
    if($files.Contains($name)){throw "Native update overlaps a platform-owned file: $name"}
    $files[$name]=$nativePlan.Files[$name]
}
function Confirm-NativeSnapshot {
    $actual=if(Test-Path $versionPath){Get-Digest $versionPath}else{$null}
    if($actual -cne $versionHash){throw "GitVersion configuration changed during update. Rerun Update from the intended revision."}
    foreach($name in $settingsPlan.ExpectedHashes.Keys){
        $path=Resolve-InstallPath $name
        $actual=if(Test-Path $path){Get-Digest $path}else{$null}
        if($actual -cne $settingsPlan.ExpectedHashes[$name]){throw "Site settings changed during update: $name"}
    }
    foreach($name in $nativePlan.ExpectedHashes.Keys){
        $path=Resolve-InstallPath $name
        $actual=if(Test-Path -LiteralPath $path -PathType Leaf){Get-Digest $path}else{$null}
        if($actual -cne $nativePlan.ExpectedHashes[$name]){throw "Consumer file changed during native update: $name"}
    }
    foreach($name in $callerPlan.ExpectedHashes.Keys){
        $path=Resolve-InstallPath $name
        $actual=if(Test-Path -LiteralPath $path -PathType Leaf){Get-Digest $path}else{$null}
        if($actual -cne $callerPlan.ExpectedHashes[$name]){throw "Consumer workflow changed during update: $name"}
    }
    $lockDigest=if(Test-Path $actionsLockPath){Get-Digest $actionsLockPath}else{$null}
    if($lockDigest -cne $actionsLockBefore){throw 'Actions lockfile changed during update.'}
}
Confirm-NativeSnapshot
# Preflight ALL managed destinations. Never silently replace consumer work.
$conflicts=[Collections.Generic.List[string]]::new()
if($previous){
    foreach($name in $previous.managedFiles.Keys){
        # Legacy whole-file callers become site-owned after semantic preflight.
        if($callerPlan.Files.Contains($name) -or $settingsPlan.Files.Contains($name) -or $name -in $settingsPlan.Retired){continue}
        if(-not $files.Contains($name) -and $name -cnotin @('bootstrap.ps1','Resolve-OpenGuidePlatform.ps1')){throw "Managed file retirement needs explicit migration: $name"}
        $path=Resolve-InstallPath $name
        if(-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Digest $path) -cne $previous.managedFiles[$name]){$conflicts.Add($name)}
    }
}
foreach($name in $files.Keys){
    $path=Resolve-InstallPath $name
    if(-not $versionFiles.ContainsKey($name) -and -not $settingsPlan.Files.Contains($name) -and -not $nativePlan.Files.Contains($name) -and -not $callerPlan.Files.Contains($name) -and (Test-Path -LiteralPath $path) -and (-not $previous -or -not $previous.managedFiles.ContainsKey($name))){$conflicts.Add($name)}
}
if($conflicts.Count){throw "Managed-file conflicts; reconcile on your review branch before retrying: $($conflicts -join ', ')"}
$hashes=[ordered]@{}
foreach($name in $files.Keys){if($versionFiles.ContainsKey($name) -or $settingsPlan.Files.Contains($name) -or $nativePlan.Files.Contains($name) -or $callerPlan.Files.Contains($name)){continue};$hashes[$name]=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($files[$name])).ToLowerInvariant()}
$record=[ordered]@{schemaVersion=1;kind='preview-installation';releaseTag=$ReleaseTag;sourcePath=$SourcePath;release=$manifest;hugoResolution='native-module';nativeHugoModule=$native;nativeChecksums=@{sum=$nativePlan.Sum;goModSum=$nativePlan.GoModSum};adoptionBlockers=@('Coordinated agent controls and independent enforcement');managedFiles=$hashes}
$record.workflowCallers=$callerPlan.Callers
$record.workflowReference=$settingsPlan.WorkflowReference
$files['.OpenGuidePlatform/installation.json']=[Text.Encoding]::UTF8.GetBytes(($record|ConvertTo-Json -Depth 30)+[Environment]::NewLine)
Write-Host "Selected $ReleaseTag ($($manifest.sourceCommit)); planned files (including site-owned caller references):"
$files.Keys|ForEach-Object {Write-Host "  $_"}
$action="Install coordinated platform files from $ReleaseTag"
if($reviewBranch){$action="Create review branch $reviewBranch and $action"}
if(-not $PSCmdlet.ShouldProcess($root,$action)){return}
Confirm-NativeSnapshot
$currentBranch=(& git -C $root branch --show-current).Trim()
if($LASTEXITCODE -ne 0 -or $currentBranch -cne $branch){throw 'Checkout changed during installation; retry from the intended branch.'}
if($reviewBranch){
    & git -C $root switch -c $reviewBranch
    if($LASTEXITCODE -ne 0){throw 'Could not create the adoption/update review branch.'}
}
# Roll back tracked files if a write fails. The installation record is written last.
$original=@{};$written=[Collections.Generic.List[string]]::new()
try{
    $lockName='.github/workflows/actions.lock'
    $original[$lockName]=if(Test-Path $actionsLockPath){[IO.File]::ReadAllBytes($actionsLockPath)}else{$null}
    $written.Add($lockName)
    $retired=@()
    if($previous){$retired=@(@('bootstrap.ps1','Resolve-OpenGuidePlatform.ps1')|Where-Object {$previous.managedFiles.ContainsKey($_)})}
    if($previousPath -eq $legacyLockPath -and (Test-Path $legacyLockPath)){$retired+=@('open-guide-platform.installation.json')}
    $retired+=@($settingsPlan.Retired)
    foreach($name in $retired){
        $path=Resolve-InstallPath $name
        $original[$name]=[IO.File]::ReadAllBytes($path);$written.Add($name)
        [IO.File]::Delete($path)
    }
    foreach($name in $files.Keys){
        # Lock the new references before committing the installation record.
        if($name -eq '.OpenGuidePlatform/installation.json'){
            Push-Location $root
            try{
                $callerPaths=@($callerPlan.Files.Keys)
                & gh actions-lock --no-narrow --no-migrate-local-actions --no-interactive @callerPaths
                if($LASTEXITCODE -ne 0){throw 'Actions locking failed. Install github/gh-actions-lock and reconcile its findings before retrying.'}
                $verification=& gh actions-lock --verify-local --json @callerPaths
                if($LASTEXITCODE -ne 0){throw 'Actions lockfile verification failed.'}
                $verification=$verification|ConvertFrom-Json -ErrorAction Stop
                if($verification.valid -isnot [bool] -or -not $verification.valid){throw 'Actions lockfile verification failed.'}
                # The tool verifies supported action dependencies. Reusable workflows
                # are excluded by GitHub; an OGP-only caller needs no actions.lock file.
            }finally{Pop-Location}
        }
        $path=Resolve-InstallPath $name
        $original[$name]=if(Test-Path -LiteralPath $path){[IO.File]::ReadAllBytes($path)}else{$null}
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null
        $written.Add($name)
        if($name -in @('AGENTS.md','CLAUDE.md')){
            [IO.File]::Delete($path)
            New-Item -ItemType SymbolicLink -Path $path -Target '.agents/agents.md' -WhatIf:$false | Out-Null
        }else{[IO.File]::WriteAllBytes($path,$files[$name])}
    }
}catch{
    foreach($name in $written){
        $path=Resolve-InstallPath $name
        if($null -eq $original[$name]){[IO.File]::Delete($path)}elseif($name -in @('AGENTS.md','CLAUDE.md')){[IO.File]::Delete($path);New-Item -ItemType SymbolicLink -Path $path -Target '.agents/agents.md' -WhatIf:$false | Out-Null}else{[IO.File]::WriteAllBytes($path,$original[$name])}
    }
    throw
}
Write-Host "Installed $ReleaseTag. Review git diff, run ./build.ps1, then commit the adoption/update PR. No deployment was enabled."

}
function Update-GuideSitePlatform {
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[ValidateSet('Auto','Local','Preview','Production','Path')][string]$PlatformSource='Auto',[string]$PlatformPath,[string]$PlatformRelease,[ValidateSet('','preview','production')][string]$Ring)
if($Ring){
    if($PlatformSource -ne 'Auto' -or $PlatformPath){throw 'Select an update ring or an explicit platform source/path, not both.'}
    $PlatformSource=if($Ring -eq 'production'){'Production'}else{'Preview'}
}
$record=Get-Content "$WorkspaceRoot/.OpenGuidePlatform/installation.json" -Raw|ConvertFrom-Json
$settings=& "$PSScriptRoot/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $WorkspaceRoot -ReadSettings
if($settings -and -not $PlatformRelease -and -not $PlatformPath -and (($PlatformSource -eq 'Auto' -and -not $Ring) -or $settings.platform.version -match '^v[0-9]+(?:\.[0-9]+)?$')){
    $PlatformRelease=[string]$settings.platform.version
    if(-not $Ring -and $PlatformSource -eq 'Auto'){$PlatformSource=if($settings.platform.ring -eq 'production'){'Production'}else{'Preview'}}
}
if($PlatformSource -eq 'Auto' -and -not $PlatformPath -and -not $PlatformRelease){$PlatformSource=if($record.release.channel -eq 'stable'){'Production'}else{'Preview'}}
$package=& "$PSScriptRoot/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $WorkspaceRoot -PlatformSource $PlatformSource -PlatformPath $PlatformPath -PlatformRelease $PlatformRelease
if(-not (Test-Path "$package/release-manifest.json")){throw 'An update needs a packaged release with its manifest. Build the local candidate package first, then supply its ZIP path.'}
if($PlatformPath){
    $selectedManifest=Get-Content "$package/release-manifest.json" -Raw|ConvertFrom-Json
    [IO.File]::WriteAllText("$package/platform-selection.json",(@{version=('v'+$selectedManifest.version);ring=$(if($selectedManifest.channel -eq 'preview'){'preview'}else{'production'})}|ConvertTo-Json))
}
# Run the target release's migration, not stale installation logic.
$next=Import-Module "$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/OpenGuidePlatform.PowerShell.GuideSiteAdoption.psm1" -Force -PassThru
& $next { param($Package,$Root,$Preview) Invoke-GuideSiteAdoption -PackageRoot $Package -WorkspaceRoot $Root -Update -WhatIf:$Preview } $package $WorkspaceRoot $WhatIfPreference
}
Export-ModuleMember -Function Invoke-GuideSiteAdoption,Update-GuideSitePlatform
