#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('PublishPrepare','ConfirmDeployment','InstallDeploymentDependencies','Deploy')][string]$Operation)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1') -Force
Invoke-GuideSiteGitHubAction -Operation $Operation
