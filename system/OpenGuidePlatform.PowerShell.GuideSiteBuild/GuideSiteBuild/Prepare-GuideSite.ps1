#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkspaceRoot,
    [Parameter(Mandatory)][string]$PolicyPath,
    [string]$EffectiveProductionPath,
    [string]$InputFailure,
    $ExpectedInputs,
    [hashtable]$InputArguments,
    [string]$SummaryPath=$env:GITHUB_STEP_SUMMARY,
    [string]$PlatformVersion='0.0.0',[string]$ModulePath='github.com/nkdAgility/HugoGuides/module',
    [string[]]$Languages,
    [string[]]$ConfigFiles,
    [string[]]$ProductionConfigFiles=@('hugo.yaml','hugo.production.yaml'),
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][string]$OutputPath,
    [ValidateSet('local','canary','preview','production')][string]$Target='local'
)
$ErrorActionPreference='Stop'
$platformRoot=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
Import-Module (Join-Path $platformRoot 'system/OpenGuidePlatform.PowerShell.GuideSiteBuild/OpenGuidePlatform.PowerShell.GuideSiteBuild.psm1')
$policyDigest=$null;$pdfReceipts=$null
try {
    if($InputFailure){throw $InputFailure}
    Import-Module (Join-Path $platformRoot 'system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1')
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
    # Prepare inspects authored catalogue files. It must not render scratch sites to
    # establish effective runtime translations; those are not source evidence.
    $sourceEvidence=@{}
    if($policy.wrapper.requiredI18nKeys.Count){
        if(-not $ConfigFiles){$ConfigFiles=@('hugo.yaml',"hugo.$Target.yaml")}
        $sourceEvidence.EffectiveTranslations=@(Get-GuideSourceTranslations -SourcePath $source -ConfigFiles $ConfigFiles -Target $Target -RequiredKeys $policy.wrapper.requiredI18nKeys)
    }
    $assessment=Get-GuideAssessment -WorkspaceRoot $WorkspaceRoot -Policy $policy -Languages $Languages -EffectiveProduction $production -SourceCommit $SourceCommit -PlatformVersion $PlatformVersion -Target $Target @sourceEvidence
    $downloads=Get-GuideDownloadRequirements -WorkspaceRoot $WorkspaceRoot -Policy $policy -Target $Target -EnabledLanguages $Languages
    $pdfReceipts=Get-GuidePdfReceipts -WorkspaceRoot $WorkspaceRoot -Policy $policy -Requirements $downloads
    $legacyAliases=Test-GuideLegacyAliases -WorkspaceRoot $WorkspaceRoot -Policy $policy
    foreach($finding in @($downloads.Findings)+@($pdfReceipts.Findings)+@($legacyAliases.Findings)){
        $assessment.findings+=[ordered]@{code=$finding.Code;severity='blocker';scope='download';subject=$finding.Path;message=$finding.Message;remediation=$finding.Message;evidence=@()}
        $assessment.outcome='fail'
    }
    $latestFindings=@(Test-GuideLatestAliases -WorkspaceRoot $WorkspaceRoot -Policy $policy -Languages $Languages)
    if($latestFindings.Count){$assessment.findings+=$latestFindings;$assessment.outcome='fail'}
    $assessment.policyDigest=$policyDigest
    $selectionPath=Join-Path $WorkspaceRoot ((Split-Path $OutputPath -Parent)+'/platform-selection.json')
    if(Test-Path $selectionPath){
        $selection=Get-Content $selectionPath -Raw|ConvertFrom-Json
        $assessment.findings+=[ordered]@{code='PLATFORM_VERSION_SELECTED';severity='info';scope='platform';subject='OGP version';message="Selection: $($selection.selection); resolved: $($selection.releaseTag); OGP ring: $($selection.ring).";remediation='Use the recorded exact release to reproduce this build.';evidence=@("Commit: $($selection.sourceCommit)","SHA256: $($selection.sha256)")}
    }
    $freshness=Get-GuideModuleFreshness -SourcePath $source -ModulePath $ModulePath
    $assessment.findings+= [ordered]@{code=$freshness.Code;severity=$freshness.Severity;scope='platform';subject=$freshness.Module;message=$freshness.Message;remediation='Review the module version through the coordinated platform update process; never change the pin during Prepare.';evidence=@("Installed: $($freshness.Installed)","Latest resolved by Go: $($freshness.Latest)")}
} catch {
    $assessment=[ordered]@{schemaVersion=1;sourceCommit=$SourceCommit;platformVersion=$PlatformVersion;policyDigest=$policyDigest;target=$Target;stage='Prepare';outcome='blocked';findings=@([ordered]@{code='PREPARE_INPUT_UNAVAILABLE';severity='blocker';scope='platform';subject='Prepare inputs';message=$_.Exception.Message;remediation='Correct the policy/configuration or install the missing dependency and rerun Prepare.';evidence=@()});inventory=@{wrapper=@{state='unknown';languages=@()};guides=@()}}
}
# Finalize input evidence before rendering any pass. Preserve independent findings
# if concurrent edits invalidate the assessed snapshot.
if($null -ne $ExpectedInputs -or $null -ne $InputArguments){
    try {
        if($null -eq $ExpectedInputs -or $null -eq $InputArguments){throw 'Expected input evidence and its arguments must be supplied together.'}
        Assert-GuidePreparedInputs -Expected $ExpectedInputs -Actual (Get-GuidePreparedInputs @InputArguments)
    } catch {
        $assessment.outcome='blocked'
        $assessment.findings+=[ordered]@{code='PREPARE_INPUTS_UNVERIFIED';severity='blocker';scope='platform';subject='Assessed input snapshot';message=$_.Exception.Message;remediation='Stop concurrent edits and rerun Prepare in a fresh output directory before Build.';evidence=@()}
    }
}
$deliveryFailures=[Collections.Generic.List[string]]::new()
try {
    $report=Write-GuideAssessmentReport -Assessment $assessment -WorkspaceRoot $WorkspaceRoot -OutputPath $OutputPath
    if($pdfReceipts){[IO.File]::WriteAllText((Join-Path (Split-Path $report.JsonPath) 'pdf-receipts.json'),($pdfReceipts|ConvertTo-Json -Depth 50))}
} catch {
    $deliveryFailures.Add("Local report: $($_.Exception.Message)")
}
# Console/Actions still receive the assessment if local report storage fails.
Write-Output (ConvertTo-GuideAssessmentMarkdown $assessment)
if($SummaryPath){
    $delivery=Write-GuideAssessmentSummary -Assessment $assessment -SummaryPath $SummaryPath
    if($delivery.Outcome -ne 'delivered'){$deliveryFailures.Add("$($delivery.Channel): $($delivery.Message)")}
}
if($deliveryFailures.Count){
    throw "REPORT_DELIVERY_FAILED. Prepare assessment remains $($assessment.outcome). $($deliveryFailures -join '; ')"
}
if($assessment.outcome -ne 'pass'){throw "Prepare $($assessment.outcome). Reports: $($report.JsonPath), $($report.MarkdownPath)"}
