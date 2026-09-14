#Requires -Version 7.4
# Remote install/update entry point: irm https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/main/bootstrap.ps1 | iex
function Invoke-OpenGuidePlatformBootstrap {
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Install,[switch]$Update,[ValidateSet('preview','stable')][string]$Channel='preview',[string]$ReleaseTag,[string]$WorkspaceRoot=$PWD,[string]$PolicyPath='guide-site.policy.json')
$ErrorActionPreference='Stop'
# The loader is source infrastructure; all adoption behavior comes from the verified release.
$loader=Invoke-RestMethod 'https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/main/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1'
$resolve=[scriptblock]::Create($loader)
$package=& $resolve -WorkspaceRoot $WorkspaceRoot -PlatformSource $(if($Channel -eq 'stable'){'Production'}else{'Preview'}) -PlatformRelease $ReleaseTag
Import-Module "$package/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/OpenGuidePlatform.PowerShell.GuideSiteAdoption.psm1" -Force
Invoke-GuideSiteAdoption -PackageRoot $package -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -Install:$Install -Update:$Update -WhatIf:$WhatIfPreference
}
Invoke-OpenGuidePlatformBootstrap @args
