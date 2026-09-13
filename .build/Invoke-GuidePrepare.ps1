#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][string]$PolicyPath,
    [string]$EffectiveProductionPath,
    [string]$ModulePath='github.com/nkdAgility/HugoGuides/module',
    [string[]]$Languages,
    [string[]]$ConfigFiles,
    [string[]]$ProductionConfigFiles=@('hugo.yaml','hugo.production.yaml'),
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][string]$OutputPath,
    [ValidateSet('local','preview','production')][string]$Target='local'
)
$ErrorActionPreference='Stop'
$platformRoot=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $platformRoot 'system/OpenGuidePlatform.PowerShell.Build/OpenGuidePlatform.PowerShell.Build.psm1') -Force
$policyDigest=$null
try {
    Import-Module (Join-Path $platformRoot 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1') -Force
    $policyDigest=(Get-FileHash -LiteralPath $PolicyPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $policy=Import-GuidePolicy -Path $PolicyPath
    $source=Join-Path $WorkspaceRoot $policy.wrapper.sourcePath
    if($EffectiveProductionPath){$production=Get-Content -LiteralPath $EffectiveProductionPath -Raw|ConvertFrom-Json -AsHashtable}
    else{
        $observed=Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles $ProductionConfigFiles -Target production
        $production=$observed.Configuration
        if($observed.Diagnostics){Write-Warning $observed.Diagnostics}
    }
    if(-not $Languages){
        if(-not $ConfigFiles){$ConfigFiles=@('hugo.yaml',"hugo.$Target.yaml")}
        $observed=Get-GuideHugoConfiguration -SourcePath $source -ConfigFiles $ConfigFiles -Target $Target
        $Languages=@($observed.Configuration.languages.Keys | Where-Object { $observed.Configuration.languages[$_].disabled -ne $true })
        if($observed.Diagnostics){Write-Warning $observed.Diagnostics}
    }
    $assessment=Get-GuideAssessment -WorkspaceRoot $WorkspaceRoot -Policy $policy -Languages $Languages -EffectiveProduction $production -SourceCommit $SourceCommit -PlatformVersion '0.0.0' -Target $Target
    $assessment.policyDigest=$policyDigest
    $freshness=Get-GuideModuleFreshness -SourcePath $source -ModulePath $ModulePath
    $assessment.findings+= [ordered]@{code=$freshness.Code;severity=$freshness.Severity;scope='platform';subject=$freshness.Module;message=$freshness.Message;remediation='Review the module version through the coordinated platform update process; never change the pin during Prepare.';evidence=@("Installed: $($freshness.Installed)","Latest resolved by Go: $($freshness.Latest)")}
} catch {
    $assessment=[ordered]@{schemaVersion=1;sourceCommit=$SourceCommit;platformVersion='0.0.0';policyDigest=$policyDigest;target=$Target;stage='Prepare';outcome='blocked';findings=@([ordered]@{code='PREPARE_INPUT_UNAVAILABLE';severity='blocker';scope='platform';subject='Prepare inputs';message=$_.Exception.Message;remediation='Correct the policy/configuration or install the missing dependency and rerun Prepare.';evidence=@()});inventory=@{wrapper=@{state='unknown';languages=@()};guides=@()}}
}
$report=Write-GuideAssessmentReport -Assessment $assessment -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath
Write-Output (Get-Content -LiteralPath $report.MarkdownPath -Raw)
if($assessment.outcome -ne 'pass'){throw "Prepare $($assessment.outcome). Reports: $($report.JsonPath), $($report.MarkdownPath)"}