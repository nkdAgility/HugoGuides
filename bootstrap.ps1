#Requires -Version 7.4
function Invoke-OpenGuidePlatformBootstrap {
[CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='Auto')]
param(
    [Parameter(ParameterSetName='Install')][switch]$Install,
    [Parameter(ParameterSetName='Update')][switch]$Update,
    [Parameter(ParameterSetName='Restore')][switch]$Restore,
    [ValidateSet('preview','stable')][string]$Channel='preview',
    [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$ReleaseTag,
    [string]$WorkspaceRoot=$PWD,
    [string]$PolicyPath='guide-site.policy.json'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repository='nkdAgility/OpenGuidePlatform'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
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
$lockPath=Resolve-InstallPath 'open-guide-platform.installation.json'
$previous=if(Test-Path -LiteralPath $lockPath){Get-Content -LiteralPath $lockPath -Raw|ConvertFrom-Json -AsHashtable}else{$null}
$automatic=-not ($Install -or $Update -or $Restore)
if($automatic){
    if($previous){$Update=$true}else{$Install=$true}
}
if($previous -and ($previous.kind -cne 'preview-installation' -or $previous.schemaVersion -ne 1)){throw 'Unsupported installation record.'}
if($Restore -or $Update){if(-not $previous){throw 'No installation found; run -Install first.'}}
if($Install -and $previous){throw 'Already installed; use -Update.'}
if(-not $Restore){
    if($Channel -ne 'preview'){throw 'Stable adoption is not available: native Hugo publication and coordinated agent controls remain adoption blockers.'}
    $branch=(& git -C $root branch --show-current).Trim()
    if($automatic -and $branch -in @('main','master')){
        $reviewBranch='codex/platform-adoption-'+[guid]::NewGuid().ToString('N').Substring(0,8)
        & git -C $root switch -c $reviewBranch
        if($LASTEXITCODE -ne 0){throw 'Could not create the adoption/update review branch.'}
        $branch=$reviewBranch
    }
    if($LASTEXITCODE -ne 0 -or -not $branch -or $branch -in @('main','master')){throw 'Install/update requires a checked-out review branch, not main/master or detached HEAD.'}
    if($Update){$PolicyPath=$previous.policyPath}
    $policyFile=Resolve-InstallPath $PolicyPath
    if(-not (Test-Path -LiteralPath $policyFile -PathType Leaf)){throw "Supply an existing reviewed guide-site policy with -PolicyPath; missing $PolicyPath"}
    $policy=Get-Content -LiteralPath $policyFile -Raw|ConvertFrom-Json
    if(-not $policy.siteId){throw 'The policy must declare siteId.'}
}
if($Restore){
    $ReleaseTag=$previous.releaseTag
    $manifest=$previous.release
}else{
    if(-not $ReleaseTag){
        $releases=Invoke-GitHub @('api',"repos/$repository/releases?per_page=100",'--paginate','--slurp','--jq','add') | ConvertFrom-Json
        $eligible=@($releases|Where-Object { -not $_.draft -and $_.prerelease -and @($_.assets|Where-Object name -eq 'bootstrap.ps1').Count -eq 1 }|Sort-Object published_at -Descending)
        if(-not $eligible.Count){throw 'No installable preview release is available.'}
        $ReleaseTag=$eligible[0].tag_name
    }
    $release=Invoke-GitHub @('release','view',$ReleaseTag,'--repo',$repository,'--json','tagName,targetCommitish,isDraft,isPrerelease')|ConvertFrom-Json
    if($release.isDraft -or -not $release.isPrerelease -or $release.tagName -cne $ReleaseTag){throw 'Select a published preview release.'}
}
# Downloads and extraction are disposable; tracked files are untouched until all checks pass.
$work=Resolve-InstallPath ('.processing/platform-install/'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work)|Out-Null
if(-not $Restore){
    $null=Invoke-GitHub @('release','download',$ReleaseTag,'--repo',$repository,'--pattern','release-manifest.json','--dir',$work)
    $manifest=Get-Content "$work/release-manifest.json" -Raw|ConvertFrom-Json -AsHashtable
    if($manifest.sourceCommit -cne $release.targetCommitish){throw 'Release source does not match manifest.'}
}
if($manifest.product -cne 'OpenGuidePlatform' -or $manifest.version -cne $ReleaseTag.Substring(1) -or $manifest.channel -cne 'preview' -or $manifest.archive -cne 'OpenGuidePlatform.zip' -or $manifest.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $manifest.sourceCommit -cnotmatch '^[a-f0-9]{40}$'){throw 'Invalid release identity.'}
$cache=Resolve-InstallPath ('.processing/platform-cache/'+$manifest.sha256)
[IO.Directory]::CreateDirectory($cache)|Out-Null
$archivePath=Join-Path $cache 'OpenGuidePlatform.zip'
if(-not (Test-Path -LiteralPath $archivePath)){
    $null=Invoke-GitHub @('release','download',$ReleaseTag,'--repo',$repository,'--pattern','OpenGuidePlatform.zip','--dir',$work)
    if((Get-Digest "$work/OpenGuidePlatform.zip") -cne $manifest.sha256){throw 'Package digest mismatch.'}
    [IO.File]::Copy("$work/OpenGuidePlatform.zip",$archivePath)
}
if((Get-Digest $archivePath) -cne $manifest.sha256){throw 'Cached package digest mismatch; remove the corrupt cache file and restore again.'}
$zip=[IO.Compression.ZipFile]::OpenRead($archivePath)
try{
    $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $zip.Entries){
        if($entry.FullName -match '(^/|\\|:|(^|/)\.\.(/|$))' -or -not $names.Add($entry.FullName)){throw 'Unsafe or duplicate package entry.'}
    }
}finally{$zip.Dispose()}
$package=Join-Path $work 'package'
[IO.Compression.ZipFile]::ExtractToDirectory($archivePath,$package)
$metadata=Get-Content "$package/platform.json" -Raw|ConvertFrom-Json
if($metadata.version -cne $manifest.version -or $metadata.sourceCommit -cne $manifest.sourceCommit){throw 'Installed package identity mismatch.'}
if($Restore){return $package}
foreach($required in @('system/OpenGuidePlatform.GuideSite.Adoption/build.ps1','system/OpenGuidePlatform.GuideSite.Adoption/main.yaml')){
    if(-not (Test-Path -LiteralPath "$package/$required" -PathType Leaf)){throw 'This release predates guide-site installation support; choose a newer release.'}
}
if(-not (Test-Json -Json (Get-Content $policyFile -Raw) -SchemaFile "$package/system/OpenGuidePlatform.PowerShell.Core/Contracts/site-policy.schema.json" -ErrorAction Stop)){throw 'Invalid guide-site policy.'}
$files=[ordered]@{}
$null=Invoke-GitHub @('release','download',$ReleaseTag,'--repo',$repository,'--pattern','bootstrap.ps1','--dir',$work)
if((Get-Digest "$work/bootstrap.ps1") -cne $manifest.bootstrapSha256){throw 'Bootstrap digest mismatch.'}
$files['bootstrap.ps1']=[IO.File]::ReadAllBytes("$work/bootstrap.ps1")
$files['build.ps1']=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.GuideSite.Adoption/build.ps1")
$workflow=[IO.File]::ReadAllText("$package/system/OpenGuidePlatform.GuideSite.Adoption/main.yaml")
$workflow=$workflow.Replace('__RELEASE__',$ReleaseTag).Replace('__COMMIT__',$manifest.sourceCommit).Replace('__POLICY__',($PolicyPath|ConvertTo-Json -Compress)).Replace('__SITE__',([string]$policy.siteId|ConvertTo-Json -Compress))
$files['.github/workflows/main.yaml']=[Text.Encoding]::UTF8.GetBytes($workflow)
foreach($item in Get-ChildItem "$package/system/OpenGuidePlatform.AgentSkills" -File -Recurse){
    $relative=[IO.Path]::GetRelativePath("$package/system/OpenGuidePlatform.AgentSkills",$item.FullName).Replace('\','/')
    $files[".agents/skills/$relative"]=[IO.File]::ReadAllBytes($item.FullName)
}
$instructions=[IO.File]::ReadAllBytes("$package/system/OpenGuidePlatform.GuideSite.Adoption/AgentInstructions.md")
$files['.agents/agents.md']=$instructions
$files['AGENTS.md']=$instructions
$files['CLAUDE.md']=$instructions
# Fail before any tracked changes if this machine cannot create Git-compatible shims.
try{New-Item -ItemType SymbolicLink -Path (Join-Path $work 'shim-test') -Target '.agents/agents.md' -WhatIf:$false | Out-Null}
catch{throw 'Symbolic links are required. Enable Windows Developer Mode (or use an elevated shell), and clone with git -c core.symlinks=true.'}
$files['.github/copilot-instructions.md']=$instructions
# Preflight ALL managed destinations. Never silently replace consumer work.
$conflicts=[Collections.Generic.List[string]]::new()
if($previous){
    foreach($name in $previous.managedFiles.Keys){
        if(-not $files.Contains($name)){throw "Managed file retirement needs explicit migration: $name"}
        $path=Resolve-InstallPath $name
        if(-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Digest $path) -cne $previous.managedFiles[$name]){$conflicts.Add($name)}
    }
}
foreach($name in $files.Keys){
    $path=Resolve-InstallPath $name
    if((Test-Path -LiteralPath $path) -and (-not $previous -or -not $previous.managedFiles.ContainsKey($name))){$conflicts.Add($name)}
}
if($conflicts.Count){throw "Managed-file conflicts; reconcile on your review branch before retrying: $($conflicts -join ', ')"}
$hashes=[ordered]@{}
foreach($name in $files.Keys){$hashes[$name]=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($files[$name])).ToLowerInvariant()}
$record=[ordered]@{schemaVersion=1;kind='preview-installation';releaseTag=$ReleaseTag;policyPath=$PolicyPath;release=$manifest;hugoResolution='verified-package-overlay';adoptionBlockers=@('Native Hugo module publication','Coordinated agent controls and independent enforcement');managedFiles=$hashes}
$files['open-guide-platform.installation.json']=[Text.Encoding]::UTF8.GetBytes(($record|ConvertTo-Json -Depth 30)+[Environment]::NewLine)
Write-Host "Selected $ReleaseTag ($($manifest.sourceCommit)); managed files:"
$files.Keys|ForEach-Object {Write-Host "  $_"}
if(-not $PSCmdlet.ShouldProcess($root,"Install coordinated preview files from $ReleaseTag")){return}
# Roll back tracked files if a write fails. The installation record is written last.
$original=@{};$written=[Collections.Generic.List[string]]::new()
try{
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
Invoke-OpenGuidePlatformBootstrap @args
