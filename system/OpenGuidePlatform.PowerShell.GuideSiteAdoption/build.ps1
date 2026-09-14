#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('All','Prepare','Build','Validate','Serve','Deploy','Verify')][string]$Stage='All',
    [ValidateSet('local','preview','production')][string]$Target='local',
    [ValidateSet('Auto','Local','Preview','Production','Path')][string]$PlatformSource='Auto',
    [string]$PlatformPath,[string]$PlatformRelease,
    [string]$OutputPath,[string]$BaseUrl,[string]$DeploymentUrl,[string]$DeploymentEnvironment
)
$ErrorActionPreference='Stop'
$lock=Get-Content "$PSScriptRoot/open-guide-platform.installation.json" -Raw|ConvertFrom-Json
$platform=& "$PSScriptRoot/Resolve-OpenGuidePlatform.ps1" -WorkspaceRoot $PSScriptRoot -PlatformSource $PlatformSource -PlatformPath $PlatformPath -PlatformRelease $PlatformRelease
Import-Module "$platform/system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1" -Force
$arguments=@{}+$PSBoundParameters
foreach($name in @('PlatformSource','PlatformPath','PlatformRelease')){$arguments.Remove($name)}
Invoke-GuideSiteBuild -WorkspaceRoot $PSScriptRoot -PolicyPath $lock.policyPath @arguments
