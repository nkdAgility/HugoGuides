#Requires -Version 7.4
[CmdletBinding(DefaultParameterSetName='Release')]
param(
    [Parameter(ParameterSetName='Release')][ValidatePattern('^(?:v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)?$')][string]$ReleaseTag,
    [Parameter(Mandatory,ParameterSetName='Candidate')][uri]$PackageUrl,
    [Parameter(Mandatory,ParameterSetName='Candidate')][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$PackageSha256,
    [Parameter(Mandatory,ParameterSetName='Candidate')][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$ExpectedVersion,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,
    [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference='Stop'
function Expand-VerifiedPlatformArchive([string]$Path,[string]$Destination) {
    $archive=[IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach($entry in $archive.Entries){
            if($entry.FullName -match '(^/|\\|:|(^|/)\.\.?(/|$))' -or -not $names.Add($entry.FullName) -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Unsafe release archive entry.'}
        }
    }finally{$archive.Dispose()}
    [IO.Compression.ZipFile]::ExtractToDirectory($Path,$Destination)
}
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$' -or $OutputPath.Split('/') -contains '..'){throw 'Install into a fresh .processing directory.'}
$output=[IO.Path]::GetFullPath((Join-Path $PWD $OutputPath))
$cursor=$output
while($cursor){if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Linked installation paths are not supported.'};$cursor=[IO.Path]::GetDirectoryName($cursor)}
if(Test-Path -LiteralPath $output){throw 'Installation output already exists.'}
$download=$output+'-download'
if(Test-Path -LiteralPath $download){throw 'Package download directory already exists.'}
[IO.Directory]::CreateDirectory($download)|Out-Null
if($PSCmdlet.ParameterSetName -eq 'Candidate'){
    if($PackageUrl.Scheme -cne 'https' -or $PackageUrl.UserInfo){throw 'Candidate package URL must use HTTPS without embedded credentials.'}
    $headers=@{}
    # Only the GitHub API receives the Actions credential. Redirects do not retain Authorization.
    if($PackageUrl.Host -ceq 'api.github.com' -and $env:GH_TOKEN){$headers.Authorization="Bearer $env:GH_TOKEN"}
    $bundle=Join-Path $download 'candidate.zip'
    Invoke-WebRequest -Uri $PackageUrl -Headers $headers -OutFile $bundle -ErrorAction Stop
    if((Get-FileHash $bundle).Hash -ine $PackageSha256){throw 'Candidate package digest mismatch.'}
    $assets=Join-Path $download 'assets'
    Expand-VerifiedPlatformArchive $bundle $assets
}else{
    if(-not $ReleaseTag){
        $items=& gh api 'repos/nkdAgility/OpenGuidePlatform/releases?per_page=100' --paginate --slurp
        if($LASTEXITCODE -ne 0){throw 'Cannot discover the platform release.'}
        $pages=$items|ConvertFrom-Json
        $matches=@($pages|ForEach-Object { $_ }|Where-Object { -not $_.draft -and $_.target_commitish -ceq $ExpectedCommit })
        if($matches.Count -ne 1){throw 'Expected one published release for the platform commit; specify ReleaseTag when ambiguous. No source-build fallback is permitted.'}
        $ReleaseTag=$matches[0].tag_name
    }
    $raw=& gh release view $ReleaseTag --repo nkdAgility/OpenGuidePlatform --json tagName,targetCommitish,isDraft 2>$null
    if($LASTEXITCODE -ne 0){throw "Release $ReleaseTag is unavailable; no source-build fallback is permitted."}
    $release=$raw|ConvertFrom-Json
    if($release.isDraft -or $release.tagName -cne $ReleaseTag -or $release.targetCommitish -cne $ExpectedCommit){throw 'Release source/tag does not match the pinned platform.'}
    & gh release download $ReleaseTag --repo nkdAgility/OpenGuidePlatform --pattern OpenGuidePlatform.zip --pattern release-manifest.json --pattern bootstrap.ps1 --dir $download
    if($LASTEXITCODE -ne 0){throw 'Release asset download failed.'}
    $assets=$download
    $ExpectedVersion=$ReleaseTag.Substring(1)
}
$manifest=Get-Content "$assets/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.product -cne 'OpenGuidePlatform' -or $manifest.version -cne $ExpectedVersion -or $manifest.sourceCommit -cne $ExpectedCommit -or $manifest.archive -cne 'OpenGuidePlatform.zip'){throw 'Release manifest does not match the requested platform.'}
if((Get-FileHash "$assets/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Release package digest mismatch.'}
# Check archive paths before extracting or importing any candidate code.
Expand-VerifiedPlatformArchive "$assets/OpenGuidePlatform.zip" $output
$metadata=Get-Content "$output/platform.json" -Raw|ConvertFrom-Json
if($metadata.product -cne 'OpenGuidePlatform' -or $metadata.sourceCommit -cne $ExpectedCommit -or $metadata.version -cne $manifest.version){throw 'Installed platform identity mismatch.'}
if((Get-FileHash "$assets/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Bootstrap digest mismatch.'}
$resolution=[ordered]@{schemaVersion=1;mode=if($PSCmdlet.ParameterSetName -eq 'Candidate'){'candidate'}else{'release'};version=$manifest.version;sourceCommit=$manifest.sourceCommit}
[IO.File]::WriteAllText("$output/platform-resolution.json",($resolution|ConvertTo-Json))
Import-Module "$output/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$output/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
Write-Host "Restored OpenGuidePlatform $ExpectedVersion ($($PSCmdlet.ParameterSetName)); SHA256 $($manifest.sha256)."
if($env:GITHUB_STEP_SUMMARY){[IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY,"## Platform restored`n`nSource: $($PSCmdlet.ParameterSetName)`n`nVersion: $ExpectedVersion`n`nCommit: $ExpectedCommit`n`nPackage SHA256: $($manifest.sha256)`n")}