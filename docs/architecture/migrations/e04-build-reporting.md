# E04 build and report foundation

Status: development implementation; E04 acceptance remains open.

The root build.ps1 now runs platform contract checks and publishing-operation tests, builds the independent reference site, and validates the artifact. Versions runs before importing test dependencies. Stage selects Prepare, Build or Validate; the bare command runs all three. Every default run receives a fresh directory under .processing/platform-build. Explicit OutputPath supports CI stage handoff and refuses existing output during Build.

The existing platform Build Site job now calls this root script for Build and Validate. GitHub continues to install Hugo and transport artifacts. Version/environment selection, workflow-level reporting and the disabled deployment job are still legacy orchestration; main.yaml is not yet the final thin shared workflow. The canary target is retained solely for that existing platform workflow; consumer policy still uses local/preview/production.

The build uses a generated configuration overlay instead of replacing tokens in source templates/configuration. It places the merged hosting configuration in the actual site artifact, enforces the 500 MB limit, checks JSON and rejects unresolved build tokens. Local, preview, production and legacy canary builds passed; local produced 76 files and the other configurations 85 each. No deployment was enabled. Existing reference warnings remain recorded, including unavailable preview.hugoguides.org and existing template/i18n warnings.

Get-GuideAssessment combines Core publication, wrapper and guide observations into the assessment v1 contract. It collects independent findings even if one edition cannot be parsed. Wrapper runtime readiness remains unknown until artifact evidence exists. Prepare can pass its own checks while explicitly listing runtime checks for the later Validate stage; it does not approve a deployment.

OpenGuidePlatform.PowerShell.Build renders the same result as escaped Markdown and writes JSON/Markdown to an immutable per-run directory. The development .build/Invoke-GuidePrepare.ps1 entry point writes reports before failing on assessment blockers. Policy/configuration parsing failures still occur before assessment output; a complete failure envelope is outstanding. Runtime environment evidence is supplied by the caller; the Hugo configuration adapter is not yet connected.

Validation: 58 Pester tests, including schema-valid aggregated failures and preservation of failed reports, plus seven skill checks and 19 contract checks. A preview assessment fixture rejects effective production enablement of Minionese. The Markdown table includes severity, scope, subject, diagnostic and remediation, followed by every observed guide/edition/language.

Remaining E04 work: effective configuration and module freshness adapters; consumer stage orchestration; complete report-on-failure behavior; Actions/PR publication with stale-run protection; effective catalogue fallback; runtime route/anchor/download/exclusion validation; deployment identity and post-deploy Verify. No consumer has adopted this candidate.