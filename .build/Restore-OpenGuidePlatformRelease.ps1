#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidatePattern('^(?:v[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)?$')][string]$ReleaseTag,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,
    [Parameter(Mandatory)][string]$OutputPath,
    [ValidateRange(0,900)][int]$WaitSeconds=0
)
$ErrorActionPreference='Stop'
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$' -or $OutputPath.Split('/') -contains '..'){throw 'Install into a fresh .processing directory.'}
$output=[IO.Path]::GetFullPath((Join-Path $PWD $OutputPath))
$cursor=$output
while($cursor){if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Linked installation paths are not supported.'};$cursor=[IO.Path]::GetDirectoryName($cursor)}
if(Test-Path -LiteralPath $output){throw 'Installation output already exists.'}
$download=$output+'-download'
if(Test-Path -LiteralPath $download){throw 'Release download directory already exists.'}
[IO.Directory]::CreateDirectory($download)|Out-Null
$timer=[Diagnostics.Stopwatch]::StartNew()
do{
    if(-not $ReleaseTag){
    $items=& gh api 'repos/nkdAgility/OpenGuidePlatform/releases?per_page=100' 2>$null
    if($LASTEXITCODE -eq 0){
        $matches=@(($items|ConvertFrom-Json)|Where-Object { -not $_.draft -and $_.target_commitish -ceq $ExpectedCommit })
        if($matches.Count -gt 1){throw 'Multiple releases match the platform commit; specify an exact ReleaseTag.'}
        if($matches.Count -eq 1){$ReleaseTag=$matches[0].tag_name}
    }
}
$raw=$null
if($ReleaseTag){$raw=& gh release view $ReleaseTag --repo nkdAgility/OpenGuidePlatform --json tagName,targetCommitish,isDraft 2>$null}
else{$global:LASTEXITCODE=1}
    if($LASTEXITCODE -eq 0){break}
    if($timer.Elapsed.TotalSeconds -ge $WaitSeconds){throw "Release $ReleaseTag is unavailable. Check the OpenGuidePlatform release workflow; no source-build fallback is permitted."}
    Write-Host "Waiting for exact release $ReleaseTag ($([int]$timer.Elapsed.TotalSeconds)s)."
    Start-Sleep -Seconds 10
}while($true)
$release=$raw|ConvertFrom-Json
if($release.isDraft -or $release.tagName -cne $ReleaseTag -or $release.targetCommitish -cne $ExpectedCommit){throw 'Release source/tag does not match the pinned platform.'}
& gh release download $ReleaseTag --repo nkdAgility/OpenGuidePlatform --pattern OpenGuidePlatform.zip --pattern release-manifest.json --dir $download
if($LASTEXITCODE -ne 0){throw 'Release asset download failed.'}
$manifest=Get-Content "$download/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.product -cne 'OpenGuidePlatform' -or $manifest.version -cne $ReleaseTag.Substring(1) -or $manifest.sourceCommit -cne $ExpectedCommit -or $manifest.archive -cne 'OpenGuidePlatform.zip'){throw 'Release manifest does not match the requested platform.'}
if((Get-FileHash "$download/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Release package digest mismatch.'}
$archive=[IO.Compression.ZipFile]::OpenRead("$download/OpenGuidePlatform.zip")
try{
    foreach($entry in $archive.Entries){
        if($entry.FullName -match '(^/|\\|:|(^|/)\.\.(/|$))'){throw 'Unsafe release archive entry.'}
    }
}finally{$archive.Dispose()}
[IO.Compression.ZipFile]::ExtractToDirectory("$download/OpenGuidePlatform.zip",$output)
$metadata=Get-Content "$output/platform.json" -Raw|ConvertFrom-Json
if($metadata.sourceCommit -cne $ExpectedCommit -or $metadata.version -cne $manifest.version){throw 'Installed platform identity mismatch.'}
Import-Module "$output/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$output/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
Write-Host "Restored $ReleaseTag from GitHub Release; SHA256 $($manifest.sha256)."
if($env:GITHUB_STEP_SUMMARY){[IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY,"## Released platform restored`n`nRelease: $ReleaseTag`n`nCommit: $ExpectedCommit`n`nPackage SHA256: $($manifest.sha256)`n")}
