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
$reviewBranch=$null
if($true){
    $branch=(& git -C $root branch --show-current).Trim()
    if($automatic -and $branch -in @('main','master')){
        $reviewBranch='codex/platform-adoption-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    }
    if($LASTEXITCODE -ne 0 -or -not $branch -or ($branch -in @('main','master') -and -not $reviewBranch)){throw 'Install/update requires a checked-out review branch, not main/master or detached HEAD.'}
    if($Update -and $previous.ContainsKey('sourcePath')){$SourcePath=$previous.sourcePath}
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
$files=[ordered]@{}
$files['build.ps1']=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/build.ps1")
$files['.OpenGuidePlatform/Resolve-OpenGuidePlatform.ps1']=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1")
$workflow=[IO.File]::ReadAllText("$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/main.yaml")
$workflow=$workflow.Replace('__RELEASE__',$ReleaseTag).Replace('__COMMIT__',$manifest.sourceCommit).Replace('__SOURCE__',($SourcePath|ConvertTo-Json -Compress))
$files['.github/workflows/main.yaml']=[Text.Encoding]::UTF8.GetBytes($workflow)
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
catch{throw 'Symbolic links are required. Enable Windows Developer Mode (or use an elevated shell), run git config --global core.symlinks true before cloning.'}
$files['.github/copilot-instructions.md']=$instructions
# Native dependency/configuration patches remain consumer-owned.
foreach($name in $nativePlan.Files.Keys){
    if($files.Contains($name)){throw "Native update overlaps a platform-owned file: $name"}
    $files[$name]=$nativePlan.Files[$name]
}
function Confirm-NativeSnapshot {
    foreach($name in $nativePlan.ExpectedHashes.Keys){
        $path=Resolve-InstallPath $name
        $actual=if(Test-Path -LiteralPath $path -PathType Leaf){Get-Digest $path}else{$null}
        if($actual -cne $nativePlan.ExpectedHashes[$name]){throw "Consumer file changed during native update: $name"}
    }
}
Confirm-NativeSnapshot
# Preflight ALL managed destinations. Never silently replace consumer work.
$conflicts=[Collections.Generic.List[string]]::new()
if($previous){
    foreach($name in $previous.managedFiles.Keys){
        if(-not $files.Contains($name) -and $name -cnotin @('bootstrap.ps1','Resolve-OpenGuidePlatform.ps1')){throw "Managed file retirement needs explicit migration: $name"}
        $path=Resolve-InstallPath $name
        if(-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Digest $path) -cne $previous.managedFiles[$name]){$conflicts.Add($name)}
    }
}
foreach($name in $files.Keys){
    $path=Resolve-InstallPath $name
    if(-not $nativePlan.Files.Contains($name) -and (Test-Path -LiteralPath $path) -and (-not $previous -or -not $previous.managedFiles.ContainsKey($name))){$conflicts.Add($name)}
}
if($conflicts.Count){throw "Managed-file conflicts; reconcile on your review branch before retrying: $($conflicts -join ', ')"}
$hashes=[ordered]@{}
foreach($name in $files.Keys){if($nativePlan.Files.Contains($name)){continue};$hashes[$name]=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($files[$name])).ToLowerInvariant()}
$record=[ordered]@{schemaVersion=1;kind='preview-installation';releaseTag=$ReleaseTag;sourcePath=$SourcePath;release=$manifest;hugoResolution='native-module';nativeHugoModule=$native;nativeChecksums=@{sum=$nativePlan.Sum;goModSum=$nativePlan.GoModSum};adoptionBlockers=@('Coordinated agent controls and independent enforcement');managedFiles=$hashes}
$files['.OpenGuidePlatform/installation.json']=[Text.Encoding]::UTF8.GetBytes(($record|ConvertTo-Json -Depth 30)+[Environment]::NewLine)
Write-Host "Selected $ReleaseTag ($($manifest.sourceCommit)); managed files:"
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
    $retired=@()
    if($previous){$retired=@(@('bootstrap.ps1','Resolve-OpenGuidePlatform.ps1')|Where-Object {$previous.managedFiles.ContainsKey($_)})}
    if($previousPath -eq $legacyLockPath -and (Test-Path $legacyLockPath)){$retired+=@('open-guide-platform.installation.json')}
    foreach($name in $retired){
        $path=Resolve-InstallPath $name
        $original[$name]=[IO.File]::ReadAllBytes($path);$written.Add($name)
        [IO.File]::Delete($path)
    }
    foreach($name in $files.Keys){
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
if($PlatformSource -eq 'Auto' -and -not $PlatformPath -and -not $PlatformRelease){$PlatformSource=if($record.release.channel -eq 'stable'){'Production'}else{'Preview'}}
$package=& "$PSScriptRoot/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $WorkspaceRoot -PlatformSource $PlatformSource -PlatformPath $PlatformPath -PlatformRelease $PlatformRelease
if(-not (Test-Path "$package/release-manifest.json")){throw 'An update needs a packaged release with its manifest. Build the local candidate package first, then supply its ZIP path.'}
# Run the target release's migration, not stale installation logic.
$next=Import-Module "$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/OpenGuidePlatform.PowerShell.GuideSiteAdoption.psm1" -Force -PassThru
& $next { param($Package,$Root,$Preview) Invoke-GuideSiteAdoption -PackageRoot $Package -WorkspaceRoot $Root -Update -WhatIf:$Preview } $package $WorkspaceRoot $WhatIfPreference
}
Export-ModuleMember -Function Invoke-GuideSiteAdoption,Update-GuideSitePlatform
