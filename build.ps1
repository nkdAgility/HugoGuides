#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Platform','GuideSite')][string]$Product='Platform',
    [Parameter(Position=0)][ValidateSet('All','Prepare','Build','Package','Sample','Release','Validate','Serve','Deploy','Verify','Version','Dependencies')][string]$Stage='All',
    [ValidateSet('local','preview','production')][string]$Target='local',
    [string]$WorkspaceRoot=$PSScriptRoot,
    [string]$PolicyPath,
    [string]$OutputPath,
    [string]$Version,
    [string]$BaseUrl,[string]$ReleaseTag,[string]$DeploymentUrl,[string]$DeploymentEnvironment,
    [ValidateSet('Auto','Local','Preview','Production','Path')][string]$PlatformSource='Auto',
    [string]$PlatformPath,[string]$PlatformRelease,
    [switch]$Deploy,[switch]$DeploySample,[switch]$Publish,[string]$DeploymentAdapter,
    [switch]$Versions
)
$ErrorActionPreference='Stop'
$platform=& "$PSScriptRoot/system/OpenGuidePlatform.PowerShell.GuideSiteAdoption/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $WorkspaceRoot -PlatformSource $PlatformSource -PlatformPath $PlatformPath -PlatformRelease $PlatformRelease -DefaultPlatformRoot $PSScriptRoot -Product $Product
if($Product -eq 'GuideSite'){
    Import-Module "$platform/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1"
    Invoke-GuideSiteBuild -Stage $Stage -Target $Target -WorkspaceRoot $WorkspaceRoot -PolicyPath $PolicyPath -OutputPath $OutputPath -Version $Version -BaseUrl $BaseUrl -DeploymentUrl $DeploymentUrl -DeploymentEnvironment $DeploymentEnvironment -Deploy:$Deploy -DeploymentAdapter $DeploymentAdapter
}else{
    Import-Module "$platform/system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
    Invoke-PlatformBuild -Stage $Stage -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Version $Version -ReleaseTag $ReleaseTag -Versions:$Versions -Publish:$Publish -DeploySample:$DeploySample -DeploymentEnvironment $DeploymentEnvironment -DeploymentUrl $DeploymentUrl -DeploymentAdapter $DeploymentAdapter
}
