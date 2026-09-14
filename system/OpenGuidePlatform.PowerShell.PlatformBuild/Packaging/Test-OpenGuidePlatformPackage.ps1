#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
Import-Module "$PSScriptRoot/../../OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
$output=Resolve-GuideWorkspacePath $root $OutputPath
$manifest=Get-Content "$output/release-manifest.json" -Raw|ConvertFrom-Json
# Own the whole restore workspace so partial extraction is cleaned up too.
$validationParent=Join-Path $root '.processing/package-validation'
$validationRoot=[IO.Path]::GetFullPath((Join-Path $validationParent ([guid]::NewGuid().ToString('N'))))
try {
    $destination=& "$PSScriptRoot/../../OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $validationRoot -PlatformPath "$output/OpenGuidePlatform-GuideSite.zip" -Product Platform
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
    if(Test-Path "$destination/bootstrap.ps1"){throw 'Remote bootstrap must not be installed in a package.'}
    # Importability must not replace the caller's live modules with temporary copies.
    & (Get-Process -Id $PID).Path -NoProfile -Command {
        param($package)
        $ErrorActionPreference='Stop'
        Import-Module "$package/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
        Import-Module "$package/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
        Import-Module "$package/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1" -Force
    } -args $destination
    if($LASTEXITCODE -ne 0){throw 'Packaged PowerShell modules could not be imported.'}
    "Validated GuideSite and PlatformBuild packages for OpenGuidePlatform $($manifest.version)."
} finally {
    # Delete only this invocation's generated child, never caller assets or a shared cache.
    if([IO.Path]::GetDirectoryName($validationRoot) -cne [IO.Path]::GetFullPath($validationParent)){
        throw 'Package validation cleanup path escaped its temporary workspace.'
    }
    if(Test-Path -LiteralPath $validationRoot){Remove-Item -LiteralPath $validationRoot -Recurse -Force}
}
