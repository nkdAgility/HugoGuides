#Requires -Version 7.4
[CmdletBinding()]
param([string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),[Parameter(Mandatory)][string]$OutputPath)
Import-Module "$PSScriptRoot/../system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
Invoke-PlatformBuildOperation -Operation Publish-PlatformPreviewRelease -WorkspaceRoot $WorkspaceRoot  -OutputPath $OutputPath
