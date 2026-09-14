#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module "$PSScriptRoot/../../OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
$output=Resolve-GuideWorkspacePath $root $OutputPath
$manifest=Get-Content "$output/release-manifest.json" -Raw|ConvertFrom-Json
$destination=& "$PSScriptRoot/../../OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $root -PlatformPath "$output/OpenGuidePlatform-GuideSite.zip" -Product Platform
$metadata=& "$destination/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Confirm-PlatformPackage.ps1" -PackageRoot $destination -Manifest $manifest
$module=$manifest.nativeHugoModule
if($module.path -cne 'github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides' -or $module.version -cne "v$($manifest.version)" -or $module.tag -cne "system/OpenGuidePlatform.Hugo.Guides/v$($manifest.version)" -or $module.sourceCommit -cne $manifest.sourceCommit){throw 'Native Hugo identity is not coordinated with the release.'}
if((Get-Content "$destination/system/OpenGuidePlatform.Hugo.Guides/go.mod" -First 1) -cne "module $($module.path)"){throw 'Packaged Hugo module declaration differs from its release identity.'}
if($manifest.workflow.repository -cne 'nkdAgility/OpenGuidePlatform' -or $manifest.workflow.path -cne '.github/workflows/guide-site-build.yaml' -or $manifest.workflow.version -cne "v$($manifest.version)" -or $manifest.workflow.sourceCommit -cne $manifest.sourceCommit){throw 'Workflow identity is not coordinated with the release.'}
$directories=@(Get-ChildItem "$destination/system" -Directory|Where-Object Name -ne OpenGuidePlatform.PowerShell.PlatformBuild)
if($directories.Count -ne @($manifest.packages.GuideSite.components.PSObject.Properties).Count){throw 'Component inventory differs from the package.'}
foreach($component in $directories){if($manifest.packages.GuideSite.components.($component.Name) -cne $manifest.version){throw "Component version differs: $($component.Name)"}}
foreach($path in @('system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/build.ps1','build.ps1','system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Build-GuideSite.ps1','system/OpenGuidePlatform.PowerShell.GuideSiteBuild/GuideSiteBuild/Prepare-GuideSite.ps1','system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1','system/OpenGuidePlatform.Hugo.Guides/go.mod')){
    if(-not [IO.File]::Exists((Join-Path $destination $path))){throw "Package missing $path"}
}
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
if(Test-Path "$destination/bootstrap.ps1"){throw 'Remote bootstrap must not be installed in a package.'}
Import-Module "$destination/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1" -Force
"Validated GuideSite and PlatformBuild packages for OpenGuidePlatform $($manifest.version)."
