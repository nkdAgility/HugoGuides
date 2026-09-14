#Requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module Pester -RequiredVersion 5.7.1
$configuration=New-PesterConfiguration
$configuration.Run.Path=Join-Path (Split-Path $PSScriptRoot -Parent) 'tests/Core'
$configuration.Run.PassThru=$true
$configuration.Output.Verbosity='Detailed'
$configuration.TestResult.Enabled=$false
# Fixture reports must not write into the real workflow summary.
$stepSummary=$env:GITHUB_STEP_SUMMARY
try {
    $env:GITHUB_STEP_SUMMARY=$null
    $result=Invoke-Pester -Configuration $configuration
} finally {
    $env:GITHUB_STEP_SUMMARY=$stepSummary
}
if($result.Result -ne 'Passed' -or $result.FailedCount -gt 0 -or $result.TotalCount -eq 0){throw 'Core tests failed or no tests ran.'}
& (Join-Path $PSScriptRoot 'Test-DistributedSkills.ps1')
