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
$result=Invoke-Pester -Configuration $configuration
if($result.FailedCount -gt 0 -or $result.TotalCount -eq 0){throw 'Core tests failed or no tests ran.'}
& (Join-Path $PSScriptRoot 'Test-DistributedSkills.ps1')
