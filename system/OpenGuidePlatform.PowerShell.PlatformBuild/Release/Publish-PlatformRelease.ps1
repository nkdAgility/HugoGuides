#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath,[string]$Repository='nkdAgility/OpenGuidePlatform')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Publish-PlatformWorkflowAliases.ps1"
$WorkspaceRoot=[IO.Path]::GetFullPath($WorkspaceRoot)
$OutputPath=[IO.Path]::GetFullPath($OutputPath,$WorkspaceRoot)
$manifest=Get-Content "$OutputPath/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.schemaVersion -ne 2 -or $manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$'){throw 'Invalid coordinated release version or manifest schema.'}
$prerelease=$manifest.version.Contains('-')
$channel=if($prerelease){'preview'}else{'stable'}
if($manifest.channel -cne $channel){throw 'Release channel disagrees with the built version. Rebuild the coordinated package.'}
$assets=@('OpenGuidePlatform-GuideSite.zip','OpenGuidePlatform-PlatformBuild.zip','release-manifest.json')
foreach($name in @('GuideSite','PlatformBuild')){
    $part=$manifest.packages.$name
    if($part.archive -cne "OpenGuidePlatform-$name.zip" -or $part.version -cne $manifest.version -or (Get-FileHash "$OutputPath/$($part.archive)").Hash -ine $part.sha256){throw "Release $name package identity or digest mismatch. Rebuild and validate the complete release."}
}
$commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or $commit -cne $manifest.sourceCommit){throw 'Release checkout does not match the package.'}
$tag="v$($manifest.version)"
$module=$manifest.nativeHugoModule
if($module.path -cne 'github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides' -or $module.version -cne $tag -or $module.tag -cne "system/OpenGuidePlatform.Hugo.Guides/$tag" -or $module.sourceCommit -cne $commit){throw 'Native Hugo publication identity differs from the tested release.'}
# A module under system/ requires its own subdirectory-prefixed tag. Never move it.
$remote="https://github.com/$Repository.git"
$ref="refs/tags/$($module.tag)"
$prior=@(& git ls-remote --refs $remote $ref)
if($LASTEXITCODE -ne 0){throw 'Cannot establish whether the native Hugo tag already exists.'}
if($prior.Count){
    if($prior.Count -ne 1 -or ($prior[0] -split '\s+')[0] -cne $commit){throw 'Existing native Hugo tag differs; publish a new version.'}
}else{
    & gh api "repos/$Repository/git/refs" --method POST -f "ref=$ref" -f "sha=$commit" | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Native Hugo tag publication failed; no platform release was created.'}
}
# Reruns verify an existing immutable release; they never replace assets or move tags.
$existing=& gh release view $tag --repo $Repository --json targetCommitish,isDraft,isPrerelease 2>$null
if($LASTEXITCODE -eq 0){
    $release=$existing|ConvertFrom-Json
    if($release.targetCommitish -cne $commit -or $release.isDraft -or [bool]$release.isPrerelease -ne $prerelease){throw 'Existing release identity differs.'}
    $verify=Join-Path $OutputPath ('existing-'+[guid]::NewGuid().ToString('N'))
    & gh release download $tag --repo $Repository --pattern OpenGuidePlatform-GuideSite.zip --pattern OpenGuidePlatform-PlatformBuild.zip --pattern release-manifest.json --dir $verify
    if($LASTEXITCODE -ne 0){throw 'Cannot verify existing release assets.'}
    $prior=Get-Content "$verify/release-manifest.json" -Raw|ConvertFrom-Json
    if((Get-FileHash "$verify/release-manifest.json").Hash -cne (Get-FileHash "$OutputPath/release-manifest.json").Hash){throw 'Existing release manifest differs; publish a new version, never overwrite.'}
    foreach($name in @('GuideSite','PlatformBuild')){
        $part=$manifest.packages.$name
        if((Get-FileHash "$verify/$($part.archive)").Hash -ine $part.sha256){throw 'Existing release bytes differ; publish a new source commit, never overwrite.'}
    }
    Publish-PlatformWorkflowAliases -WorkspaceRoot $WorkspaceRoot -Repository $Repository -Version $manifest.version -Commit $commit
    Write-Host "Existing immutable release $tag verified."
    return
}
$updateRing=if($prerelease){'preview'}else{'production'}
$notes=@"
## For guide-site maintainers

This is a $channel release of the shared guide-site build tools, Hugo module and agent skills. The change list below identifies the included fixes and updates.

### Update an existing site

On a review branch, run:

~~~~powershell
./build.ps1 Update -ring $updateRing -PlatformRelease $tag
./build.ps1 -Target preview
./build.ps1 -Target production
~~~~

Review and commit the coordinated update. Your settings.yaml selects an exact release or a major/minor version family for local and CI builds. The installation record remains generated. Publishing this release does not trigger your site; its next build can select a matching family update. A production site using preview OGP receives a warning, not a deployment block.

### First installation

~~~~powershell
irm https://raw.githubusercontent.com/$Repository/main/bootstrap.ps1 | iex
~~~~

Bootstrap defaults to preview. To select this exact release afterward, use the update command above. See the [installation and hosting instructions](https://github.com/$Repository/blob/$tag/readme.md) for prerequisites and first-site setup.

### Downloads

- **OpenGuidePlatform-GuideSite.zip**: build tools, Hugo integration and shared agent resources consumed by the installer; site maintainers normally do not download this manually.
- **OpenGuidePlatform-PlatformBuild.zip**: tooling for developing and packaging OGP itself.
- **release-manifest.json**: coordinated versions and checksums used to verify the packages.

The corresponding native Hugo module tag is $($module.tag). The platform tests and shared sample pipeline passed before publication. Site deployment remains a separate action.

"@
[IO.File]::WriteAllText("$OutputPath/release-notes.md",$notes)
$releaseFlags=if($prerelease){@('--prerelease','--latest=false')}else{@()}
& gh release create $tag "$OutputPath/OpenGuidePlatform-GuideSite.zip" "$OutputPath/OpenGuidePlatform-PlatformBuild.zip" "$OutputPath/release-manifest.json" --repo $Repository --target $commit @releaseFlags --title "OpenGuidePlatform $($manifest.version)" --generate-notes --notes-file "$OutputPath/release-notes.md"
if($LASTEXITCODE -ne 0){throw 'Platform release publication failed.'}

Publish-PlatformWorkflowAliases -WorkspaceRoot $WorkspaceRoot -Repository $Repository -Version $manifest.version -Commit $commit
