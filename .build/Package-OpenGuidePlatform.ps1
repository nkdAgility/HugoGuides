#Requires -Version 7.4
[CmdletBinding()]
param([string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),[Parameter(Mandatory)][string]$OutputPath,[Parameter(Mandatory)][string]$Version)
Import-Module "$PSScriptRoot/../system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
Invoke-PlatformBuildOperation -Operation Package-OpenGuidePlatform -WorkspaceRoot $WorkspaceRoot  -OutputPath $OutputPath -Version $Version
