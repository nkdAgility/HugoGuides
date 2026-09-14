#Requires -Version 7.4
[CmdletBinding()]
param([string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent))
Import-Module "$PSScriptRoot/../system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
Invoke-PlatformBuildOperation -Operation Test-PlatformContracts -WorkspaceRoot $WorkspaceRoot
