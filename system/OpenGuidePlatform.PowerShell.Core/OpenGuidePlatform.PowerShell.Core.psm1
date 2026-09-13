Set-StrictMode -Version Latest
$script:CoreRoot=$PSScriptRoot
. (Join-Path $PSScriptRoot 'Internal/Paths.ps1')
. (Join-Path $PSScriptRoot 'GuideInventory/Get-GuideLanguage.ps1')
. (Join-Path $PSScriptRoot 'AgentGovernance/Test-GuideWritePolicy.ps1')
. (Join-Path $PSScriptRoot 'TranslationReadiness/Get-GuideTranslationState.ps1')
. (Join-Path $PSScriptRoot 'PublicationPolicy/Get-GuidePolicyFinding.ps1')
. (Join-Path $PSScriptRoot 'GuideInventory/Get-GuideInventory.ps1')
. (Join-Path $PSScriptRoot 'TranslationReadiness/New-GuideTranslationScaffold.ps1')
. (Join-Path $PSScriptRoot 'ContributorManagement/Get-GuideGravatar.ps1')
. (Join-Path $PSScriptRoot 'EditionManagement/New-GuideEdition.ps1')
. (Join-Path $PSScriptRoot 'ContributorManagement/New-GuideContributions.ps1')
. (Join-Path $PSScriptRoot 'PdfPublishing/Get-GuidePdfPlan.ps1')

. (Join-Path $PSScriptRoot 'ContributorManagement/Update-GuideContributions.ps1')

. (Join-Path $PSScriptRoot 'PdfPublishing/Test-GuidePdfCache.ps1')

. (Join-Path $PSScriptRoot 'WrapperReadiness/Get-GuideWrapperStatus.ps1')

. (Join-Path $PSScriptRoot 'Assessment/Get-GuideAssessment.ps1')

. (Join-Path $PSScriptRoot 'TranslationReadiness/Set-GuideWrapperTranslation.ps1')

. (Join-Path $PSScriptRoot 'PublicationPolicy/Get-GuideDownloadRequirements.ps1')

. (Join-Path $PSScriptRoot 'PdfPublishing/Get-GuidePdfReceipts.ps1')
