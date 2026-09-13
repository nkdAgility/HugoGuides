#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
$output=Resolve-GuideWorkspacePath $root $OutputPath
$manifest=Get-Content "$output/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.product -cne 'OpenGuidePlatform' -or $manifest.archive -cne 'OpenGuidePlatform.zip'){throw 'Unexpected platform package identity.'}
if((Get-FileHash "$output/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Package digest mismatch.'}
$destination=Join-Path $output ('verified-'+[guid]::NewGuid().ToString('N'))
Expand-Archive "$output/OpenGuidePlatform.zip" $destination
$metadata=Get-Content "$destination/platform.json" -Raw|ConvertFrom-Json
if($metadata.sourceCommit -cne $manifest.sourceCommit -or $metadata.version -cne $manifest.version){throw 'Package source/version mismatch.'}
foreach($path in @('system/OpenGuidePlatform.GuideSite.Adoption/build.ps1','build.ps1','.build/Build-GuideSite.ps1','.build/Prepare-GuideSite.ps1','system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1','system/OpenGuidePlatform.Hugo.Guides/go.mod')){
    if(-not [IO.File]::Exists((Join-Path $destination $path))){throw "Package missing $path"}
}
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
"Validated distributable OpenGuidePlatform $($manifest.version). SHA256: $($manifest.sha256)"

if((Get-FileHash "$output/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Published bootstrap digest differs from manifest.'}
