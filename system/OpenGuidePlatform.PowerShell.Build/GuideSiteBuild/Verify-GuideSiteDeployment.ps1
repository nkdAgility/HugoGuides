#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$DeploymentUrl,
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$Version
)
$ErrorActionPreference='Stop'
& "$PSScriptRoot/Confirm-GuideSiteDeployment.ps1" -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath -Target $Target -Version $Version
$root=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1" -Force
Import-Module "$root/system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1" -Force
$output=Resolve-GuideWorkspacePath $WorkspaceRoot $OutputPath
$policy=Import-GuidePolicy (Resolve-GuideWorkspacePath $WorkspaceRoot $PolicyPath)
$identity=Get-Content "$output/artifact-identity.json" -Raw|ConvertFrom-Json
$forbidden=@(Get-GuideForbiddenPaths -Policy $policy -Target $Target)
$overlay=Get-Content "$output/candidate-platform.json" -Raw|ConvertFrom-Json -AsHashtable
$arguments=@{}
if($overlay.Contains('baseURL')){$arguments.ExpectedBaseUri=$overlay.baseURL}
$requiredRoutes=@($policy.wrapper.requiredRoutes|Where-Object { $route=$_; -not @($forbidden|Where-Object {$route.StartsWith("/$_/")}).Count })
$downloads=Get-Content "$output/download-requirements.json" -Raw|ConvertFrom-Json
$arguments.ForbiddenDownloads=@($downloads.ForbiddenPaths|Where-Object {$_ -cnotin $downloads.RequiredPaths})
$result=Test-GuideSiteDeployment -BaseUri $DeploymentUrl -Identity $identity -RequiredRoutes $requiredRoutes -ForbiddenPaths $forbidden @arguments
[IO.File]::WriteAllText("$output/deployment-verification.json",($result|ConvertTo-Json -Depth 30))
$markdown="## Verify: $($result.Outcome)`n`nCommit: $($result.SourceCommit)`n`nPlatform: $($result.PlatformVersion)`n`nTarget: $Target`n`nURL: $DeploymentUrl`n"
Write-Host $markdown
if($env:GITHUB_STEP_SUMMARY){[IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY,$markdown)}
if($result.Outcome -ne 'pass'){$result.Findings|Format-Table|Out-Host;throw 'Deployment verification failed; inspect deployment-verification.json.'}
