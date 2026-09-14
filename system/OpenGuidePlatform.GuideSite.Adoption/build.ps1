#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('All','Prepare','Build','Validate','Serve','Deploy','Verify')][string]$Stage='All',
    [ValidateSet('local','preview','production')][string]$Target='local',
    [string]$OutputPath,[string]$BaseUrl,[string]$DeploymentUrl,[string]$DeploymentEnvironment
)
$ErrorActionPreference='Stop'
$lock=Get-Content "$PSScriptRoot/open-guide-platform.installation.json" -Raw|ConvertFrom-Json
$platform=& "$PSScriptRoot/bootstrap.ps1" -Restore -WorkspaceRoot $PSScriptRoot
Import-Module "$platform/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
Invoke-GuideSiteBuild -WorkspaceRoot $PSScriptRoot -PolicyPath $lock.policyPath -Version $lock.release.version @PSBoundParameters
