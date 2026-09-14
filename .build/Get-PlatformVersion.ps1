#Requires -Version 7.4
[CmdletBinding()]
param([string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent))
Import-Module "$PSScriptRoot/../system/OpenGuidePlatform.PowerShell.PlatformBuild/OpenGuidePlatform.PowerShell.PlatformBuild.psm1"
$version=Get-PlatformBuildVersion -WorkspaceRoot $WorkspaceRoot
if($env:GITHUB_OUTPUT){[IO.File]::AppendAllText($env:GITHUB_OUTPUT,"semVer=$($version.SemVer)`nsha=$($version.Sha)`n")}
$version
