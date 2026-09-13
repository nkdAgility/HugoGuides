# Build reporting candidate

This component renders Core assessment v1 results and writes immutable per-run JSON/Markdown evidence. It contains no duplicated publication policy. Get-GuideAssessment lives in Core; both CLI and skills can consume the same result.

ConvertTo-GuideAssessmentMarkdown returns copy suitable for console, an Actions summary or a PR body. Write-GuideAssessmentReport validates the contract before writing and refuses existing or unsafe output locations. A partial report directory after an I/O failure is not a completed assessment; use a new run directory after investigating the failure.

The root build.ps1 currently builds the platform reference site. The .build/Invoke-GuidePrepare.ps1 development entry point accepts a reviewed policy and effective production JSON plus configured languages. It writes assessment reports before returning failure on blockers. It is not the final consumer bootstrap. GitHub comment publication, effective configuration collection and runtime Validate/Verify adapters remain E04 work.