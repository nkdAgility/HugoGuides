#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EventName,
    [AllowEmptyString()][string]$PreReleaseLabel='',
    [int]$PullRequestNumber=0,
    [string]$ProductionEnvironment='production',
    [string]$OutputPath=$env:GITHUB_OUTPUT,
    [string]$SummaryPath=$env:GITHUB_STEP_SUMMARY
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
$context=Get-GuideBuildContext -EventName $EventName -PreReleaseLabel $PreReleaseLabel -PullRequestNumber $PullRequestNumber -ProductionEnvironment $ProductionEnvironment
# Values come from the constrained domain result, never interpolated workflow expressions.
if($OutputPath){
    $outputs=@("Ring=$($context.Ring)","AzureSitesConfig=$($context.Target)","AzureSitesEnvironment=$($context.DeploymentEnvironment)")
    [IO.File]::AppendAllLines([IO.Path]::GetFullPath($OutputPath),[string[]]$outputs,[Text.UTF8Encoding]::new($false))
}
$markdown="## Build context`n`nRing: $($context.Ring)`n`nTarget: $($context.Target)`n`nDeployment remains disabled; environment selection is not deployment approval.`n"
if($SummaryPath){[IO.File]::AppendAllText([IO.Path]::GetFullPath($SummaryPath),$markdown,[Text.UTF8Encoding]::new($false))}
$context