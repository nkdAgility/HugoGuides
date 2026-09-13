#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputPath,[Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$Version)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$'){throw 'Package output must be a fresh directory under .processing.'}
$output=Resolve-GuideWorkspacePath $root $OutputPath
if(Test-Path -LiteralPath $output){throw 'Package output already exists.'}
$commit=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot resolve platform source commit.'}
[IO.Directory]::CreateDirectory($output)|Out-Null
$stage=Join-Path $output 'package'
[IO.Directory]::CreateDirectory($stage)|Out-Null
foreach($path in @('system','.build','build.ps1','LICENSE','readme.md')){
    Copy-Item -LiteralPath (Join-Path $root $path) -Destination $stage -Recurse
}
# Only distribution/runtime entry points belong in the package; repository tests stay in the checkout.
$runtime=@('Build-GuideSite.ps1','Test-GuideSiteNavigation.ps1','Prepare-GuideSite.ps1','Write-GuideSiteValidationSummary.ps1','Confirm-GuideSiteDeployment.ps1','Verify-GuideSiteDeployment.ps1')
Get-ChildItem -LiteralPath "$stage/.build" -File|Where-Object Name -NotIn $runtime|Remove-Item
$metadata=[ordered]@{schemaVersion=1;product='OpenGuidePlatform';version=$Version;sourceCommit=$commit;channel=if($Version.Contains('-')){'preview'}else{'stable'};hugoModule='github.com/nkdAgility/HugoGuides/module'}
[IO.File]::WriteAllText("$stage/platform.json",($metadata|ConvertTo-Json))
Copy-Item -LiteralPath "$root/bootstrap.ps1" -Destination "$output/bootstrap.ps1"
$archive=Join-Path $output 'OpenGuidePlatform.zip'
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
try{
    foreach($file in Get-ChildItem -LiteralPath $stage -File -Recurse -Force|Sort-Object FullName){
        $name=[IO.Path]::GetRelativePath($stage,$file.FullName).Replace('\','/')
        $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime=[DateTimeOffset]::new(2020,1,1,0,0,0,[TimeSpan]::Zero)
        $inputStream=[IO.File]::OpenRead($file.FullName);$outputStream=$entry.Open()
        try{$inputStream.CopyTo($outputStream)}finally{$inputStream.Dispose();$outputStream.Dispose()}
    }
}finally{$zip.Dispose()}
$manifest=[ordered]@{schemaVersion=1;product='OpenGuidePlatform';version=$Version;sourceCommit=$commit;channel=$metadata.channel;archive='OpenGuidePlatform.zip';bootstrapSha256=(Get-FileHash "$output/bootstrap.ps1").Hash.ToLowerInvariant();sha256=(Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()}
[IO.File]::WriteAllText("$output/release-manifest.json",($manifest|ConvertTo-Json))
"Packaged OpenGuidePlatform $Version from $commit"
