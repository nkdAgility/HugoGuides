#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot)
$ErrorActionPreference='Stop'
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -Repository PSGallery
Install-Module powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser -Force -Repository PSGallery

. (Join-Path $PSScriptRoot '../../OpenGuidePlatform.PowerShell.GuideSiteBuild/Versioning/GitVersion.ps1')
Install-GuideGitVersion -WorkspaceRoot $WorkspaceRoot