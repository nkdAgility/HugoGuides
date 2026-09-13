#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$WorkspaceRoot,[Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)]$NativeModule,[string]$PreviousVersion)
Import-Module (Join-Path $PSScriptRoot 'NativeHugoDependency.psm1') -Force
New-GuideNativeHugoUpdatePlan @PSBoundParameters
