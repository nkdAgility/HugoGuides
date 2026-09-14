#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('PublishPrepare','ConfirmDeployment')][string]$Operation)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../OpenGuidePlatform.PowerShell.Build.psm1') -Force
Invoke-GuideSiteGitHubAction -Operation $Operation
