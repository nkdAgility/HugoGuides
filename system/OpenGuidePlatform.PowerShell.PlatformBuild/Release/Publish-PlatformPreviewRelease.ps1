#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath,[string]$Repository='nkdAgility/OpenGuidePlatform')
$ErrorActionPreference='Stop'
$manifest=Get-Content "$OutputPath/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.channel -cne 'preview' -or $manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9.-]+$' -or $manifest.archive -cne 'OpenGuidePlatform.zip'){throw 'Only GitVersion prerelease packages can be published by this entry point.'}
if((Get-FileHash "$OutputPath/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Release package digest mismatch.'}
if((Get-FileHash "$OutputPath/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Bootstrap digest mismatch.'}
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
$existing=& gh release view $tag --repo $Repository --json targetCommitish,isDraft 2>$null
if($LASTEXITCODE -eq 0){
    $release=$existing|ConvertFrom-Json
    if($release.targetCommitish -cne $commit -or $release.isDraft){throw 'Existing release identity differs.'}
    $verify=Join-Path $OutputPath ('existing-'+[guid]::NewGuid().ToString('N'))
    & gh release download $tag --repo $Repository --pattern OpenGuidePlatform.zip --pattern release-manifest.json --pattern bootstrap.ps1 --dir $verify
    if($LASTEXITCODE -ne 0){throw 'Cannot verify existing release assets.'}
    $prior=Get-Content "$verify/release-manifest.json" -Raw|ConvertFrom-Json
    if($prior.sha256 -cne $manifest.sha256 -or (Get-FileHash "$verify/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Existing release bytes differ; publish a new source commit, never overwrite.'}
    if((Get-FileHash "$verify/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Existing bootstrap asset differs.'}
    Write-Host "Existing immutable release $tag verified."
    return
}
$notes=@"
Preview candidate from commit $commit.

Platform component tests and package verification passed. Before publication, GuideSiteSample consumed this build's candidate artifact through the shared guide-site workflow. Publication depends on that workflow succeeding; the release reuses the validated build assets without repackaging.

This prerelease does not deploy or update any guide instance. Hosting/browser verification and stable promotion remain separate acceptance steps.
"@
[IO.File]::WriteAllText("$OutputPath/release-notes.md",$notes)
& gh release create $tag "$OutputPath/OpenGuidePlatform.zip" "$OutputPath/release-manifest.json" "$OutputPath/bootstrap.ps1" --repo $Repository --target $commit --prerelease --latest=false --title "OpenGuidePlatform $($manifest.version)" --notes-file "$OutputPath/release-notes.md"
if($LASTEXITCODE -ne 0){throw 'Preview release publication failed.'}
