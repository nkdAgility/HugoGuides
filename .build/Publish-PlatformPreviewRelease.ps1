#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$manifest=Get-Content "$OutputPath/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.channel -cne 'preview' -or $manifest.version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9.-]+$' -or $manifest.archive -cne 'OpenGuidePlatform.zip'){throw 'Only GitVersion prerelease packages can be published by this entry point.'}
if((Get-FileHash "$OutputPath/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Release package digest mismatch.'}
if((Get-FileHash "$OutputPath/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Bootstrap digest mismatch.'}
$commit=(& git rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or $commit -cne $manifest.sourceCommit){throw 'Release checkout does not match the package.'}
$tag="v$($manifest.version)"
# Reruns verify an existing immutable release; they never replace assets or move tags.
$existing=& gh release view $tag --repo $env:GITHUB_REPOSITORY --json targetCommitish,isDraft 2>$null
if($LASTEXITCODE -eq 0){
    $release=$existing|ConvertFrom-Json
    if($release.targetCommitish -cne $commit -or $release.isDraft){throw 'Existing release identity differs.'}
    $verify=Join-Path $OutputPath ('existing-'+[guid]::NewGuid().ToString('N'))
    & gh release download $tag --repo $env:GITHUB_REPOSITORY --pattern OpenGuidePlatform.zip --pattern release-manifest.json --pattern bootstrap.ps1 --dir $verify
    if($LASTEXITCODE -ne 0){throw 'Cannot verify existing release assets.'}
    $prior=Get-Content "$verify/release-manifest.json" -Raw|ConvertFrom-Json
    if($prior.sha256 -cne $manifest.sha256 -or (Get-FileHash "$verify/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Existing release bytes differ; publish a new source commit, never overwrite.'}
    if((Get-FileHash "$verify/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Existing bootstrap asset differs.'}
    Write-Host "Existing immutable release $tag verified."
    return
}
$notes=@"
Preview candidate from commit $commit.

Platform component tests and package verification passed. GuideSiteSample independently restores this exact release through the shared guide-site workflow. Its result is required evidence before adopting the candidate.

This prerelease does not deploy or update any guide instance. Hosting/browser verification and stable promotion remain separate acceptance steps.
"@
[IO.File]::WriteAllText("$OutputPath/release-notes.md",$notes)
& gh release create $tag "$OutputPath/OpenGuidePlatform.zip" "$OutputPath/release-manifest.json" "$OutputPath/bootstrap.ps1" --repo $env:GITHUB_REPOSITORY --target $commit --prerelease --latest=false --title "OpenGuidePlatform $($manifest.version)" --notes-file "$OutputPath/release-notes.md"
if($LASTEXITCODE -ne 0){throw 'Preview release publication failed.'}
