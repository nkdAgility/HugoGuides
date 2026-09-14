#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
$output=Resolve-GuideWorkspacePath $root $OutputPath
$manifest=Get-Content "$output/release-manifest.json" -Raw|ConvertFrom-Json
if($manifest.product -cne 'OpenGuidePlatform' -or $manifest.archive -cne 'OpenGuidePlatform.zip'){throw 'Unexpected platform package identity.'}
if((Get-FileHash "$output/OpenGuidePlatform.zip").Hash.ToLowerInvariant() -cne $manifest.sha256){throw 'Package digest mismatch.'}
$destination=Join-Path $output ('verified-'+[guid]::NewGuid().ToString('N'))
Expand-Archive "$output/OpenGuidePlatform.zip" $destination
$metadata=& "$destination/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Confirm-PlatformPackage.ps1" -PackageRoot $destination -Manifest $manifest
$module=$manifest.nativeHugoModule
if($module.path -cne 'github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides' -or $module.version -cne "v$($manifest.version)" -or $module.tag -cne "system/OpenGuidePlatform.Hugo.Guides/v$($manifest.version)" -or $module.sourceCommit -cne $manifest.sourceCommit){throw 'Native Hugo identity is not coordinated with the release.'}
if((Get-Content "$destination/system/OpenGuidePlatform.Hugo.Guides/go.mod" -First 1) -cne "module $($module.path)"){throw 'Packaged Hugo module declaration differs from its release identity.'}
if($manifest.workflow.repository -cne 'nkdAgility/OpenGuidePlatform' -or $manifest.workflow.path -cne '.github/workflows/guide-site-build.yaml' -or $manifest.workflow.version -cne "v$($manifest.version)" -or $manifest.workflow.sourceCommit -cne $manifest.sourceCommit){throw 'Workflow identity is not coordinated with the release.'}
$directories=@(Get-ChildItem "$destination/system" -Directory)
if($directories.Count -ne @($manifest.components.PSObject.Properties).Count){throw 'Component inventory differs from the package.'}
foreach($component in $directories){if($manifest.components.($component.Name) -cne $manifest.version){throw "Component version differs: $($component.Name)"}}
foreach($path in @('system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/build.ps1','build.ps1','system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Build-GuideSite.ps1','system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Prepare-GuideSite.ps1','system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1','system/OpenGuidePlatform.Hugo.Guides/go.mod')){
    if(-not [IO.File]::Exists((Join-Path $destination $path))){throw "Package missing $path"}
}
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
"Validated distributable OpenGuidePlatform $($manifest.version). SHA256: $($manifest.sha256)"

if((Get-FileHash "$output/bootstrap.ps1").Hash.ToLowerInvariant() -cne $manifest.bootstrapSha256){throw 'Published bootstrap digest differs from manifest.'}
