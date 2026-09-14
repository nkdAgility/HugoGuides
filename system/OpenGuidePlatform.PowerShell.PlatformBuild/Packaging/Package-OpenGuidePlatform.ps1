#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath,[Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$Version)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
if($OutputPath -notmatch '^\.processing/[A-Za-z0-9/_-]+$'){throw 'Package output must be a fresh directory under .processing.'}
$output=Resolve-GuideWorkspacePath $root $OutputPath
if(Test-Path -LiteralPath $output){throw 'Package output already exists.'}
$commit=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot resolve platform source commit.'}
[IO.Directory]::CreateDirectory($output)|Out-Null
$stage=Join-Path $output 'package'
[IO.Directory]::CreateDirectory($stage)|Out-Null
foreach($path in @('build.ps1','LICENSE','readme.md')){
    Copy-Item -LiteralPath (Join-Path $root $path) -Destination $stage -Recurse
}
$guideComponents=@('OpenGuidePlatform.Hugo.Guides','OpenGuidePlatform.PowerShell.Core','OpenGuidePlatform.PowerShell.GuideSiteBuild','OpenGuidePlatform.PowerShell.GuideSiteAdoption','OpenGuidePlatform.PowerShell.AgentControls','OpenGuidePlatform.Agents.Integration')
[IO.Directory]::CreateDirectory("$stage/system")|Out-Null
foreach($component in $guideComponents){Copy-Item "$root/system/$component" "$stage/system/" -Recurse}
$metadata=[ordered]@{schemaVersion=1;product='OpenGuidePlatform';version=$Version;sourceCommit=$commit;channel=if($Version.Contains('-')){'preview'}else{'stable'};hugoModule='github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides'}
$metadata.nativeHugoModule=[ordered]@{path=$metadata.hugoModule;version="v$Version";tag="system/OpenGuidePlatform.Hugo.Guides/v$Version";sourceCommit=$commit}
$metadata.workflow=[ordered]@{repository='nkdAgility/OpenGuidePlatform';path='.github/workflows/guide-site-build.yaml';version="v$Version";sourceCommit=$commit}
$metadata.components=[ordered]@{}
foreach($component in Get-ChildItem "$stage/system" -Directory|Sort-Object Name){$metadata.components[$component.Name]=$Version}
$metadata.requirements=[ordered]@{powerShell='>=7.4';hugo='>=0.146.0';hugoExtended=$true;go='>=1.24.5'}
[IO.File]::WriteAllText("$stage/platform.json",($metadata|ConvertTo-Json -Depth 10))
function New-DistributionArchive([string]$stage,[string]$archive) {
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
}
$guideArchive='OpenGuidePlatform-GuideSite.zip'
New-DistributionArchive $stage (Join-Path $output $guideArchive)
$guideHash=(Get-FileHash "$output/$guideArchive").Hash.ToLowerInvariant()
$platformStage=Join-Path $output 'platform-build'
[IO.Directory]::CreateDirectory("$platformStage/system")|Out-Null
Copy-Item "$root/system/OpenGuidePlatform.PowerShell.PlatformBuild" "$platformStage/system/" -Recurse
$dependency=[ordered]@{version=$Version;sha256=$guideHash}
$platformMetadata=[ordered]@{schemaVersion=1;product='OpenGuidePlatform';package='PlatformBuild';version=$Version;sourceCommit=$commit;dependencies=@{GuideSite=$dependency}}
[IO.File]::WriteAllText("$platformStage/platform-build.json",($platformMetadata|ConvertTo-Json -Depth 10))
$platformArchive='OpenGuidePlatform-PlatformBuild.zip'
New-DistributionArchive $platformStage (Join-Path $output $platformArchive)
$manifest=[ordered]@{schemaVersion=2;product='OpenGuidePlatform';version=$Version;sourceCommit=$commit;channel=$metadata.channel;packages=[ordered]@{
    GuideSite=[ordered]@{archive=$guideArchive;version=$Version;sha256=$guideHash;components=$metadata.components}
    PlatformBuild=[ordered]@{archive=$platformArchive;version=$Version;sha256=(Get-FileHash "$output/$platformArchive").Hash.ToLowerInvariant();components=@{'OpenGuidePlatform.PowerShell.PlatformBuild'=$Version};dependencies=@{GuideSite=$dependency}}
}}
foreach($field in @('nativeHugoModule','workflow','requirements')){$manifest[$field]=$metadata[$field]}
[IO.File]::WriteAllText("$output/release-manifest.json",($manifest|ConvertTo-Json -Depth 10))
"Packaged OpenGuidePlatform $Version from $commit"
