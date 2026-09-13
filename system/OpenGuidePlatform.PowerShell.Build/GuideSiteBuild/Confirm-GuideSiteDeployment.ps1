#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$Version
)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
$output=Resolve-GuideWorkspacePath $WorkspaceRoot $OutputPath
$identity=Get-Content "$output/artifact-identity.json" -Raw|ConvertFrom-Json
if(-not $identity.PSObject.Properties['sourceDirty'] -or $identity.sourceDirty -isnot [bool] -or $identity.sourceDirty){throw 'Deploy requires an explicitly clean source identity; commit changes and rebuild.'}
$report=Get-Content "$output/artifact-validation.json" -Raw|ConvertFrom-Json
$commit=(& git -C $WorkspaceRoot rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Cannot establish deployment source commit.'}
if($report.Outcome -cne 'pass' -or $report.SourceCommit -cne $commit -or $report.Target -cne $Target -or $identity.version -cne $Version){throw 'Deploy requires passing Validate evidence for this commit, target and platform version.'}
$null=Test-GuideArtifactIdentity -ArtifactRoot "$output/site" -Identity $identity -ExpectedTarget $Target -ExpectedSourceCommit $commit
Write-Host "Deployment input verified: $commit / $Target / $Version. Hosting adapter must upload this artifact without rebuilding."
