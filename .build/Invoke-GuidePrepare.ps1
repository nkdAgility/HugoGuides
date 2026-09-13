#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$EffectiveProductionPath,
    [Parameter(Mandatory)][string[]]$Languages,
    [Parameter(Mandatory)][string]$SourceCommit,
    [Parameter(Mandatory)][string]$OutputPath,
    [ValidateSet('local','preview','production')][string]$Target='local'
)
$ErrorActionPreference='Stop'
$platformRoot=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $platformRoot 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
Import-Module (Join-Path $platformRoot 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
# Caller supplies Hugo's effective configuration evidence, never an inferred merge.
$policy=Import-GuidePolicy -Path $PolicyPath
$production=Get-Content -LiteralPath $EffectiveProductionPath -Raw | ConvertFrom-Json -AsHashtable
$assessment=Get-GuideAssessment -WorkspaceRoot $WorkspaceRoot -Policy $policy -Languages $Languages -EffectiveProduction $production -SourceCommit $SourceCommit -PlatformVersion '0.0.0' -Target $Target
$report=Write-GuideAssessmentReport -Assessment $assessment -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath
Write-Output (Get-Content -LiteralPath $report.MarkdownPath -Raw)
if($assessment.outcome -ne 'pass'){throw "Prepare $($assessment.outcome). Reports: $($report.JsonPath), $($report.MarkdownPath)"}