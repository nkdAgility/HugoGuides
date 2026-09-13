# Guide-site build and reporting adapters

Core owns publishing rules and structured assessments. This component owns Hugo configuration/probe execution, artifact validation and report delivery. Root `build.ps1 -Product GuideSite` orchestrates these operations through `.build/Build-GuideSite.ps1` and `.build/Prepare-GuideSite.ps1`.

The shared guide-site workflow restores an immutable GitHub Release before invoking its distributed build entry point. The sample has no separate packaging or source-build path in CI. See the root README for the platform/consumer workflow boundary and local commands.

`WrapperTranslations/probe.html` is an adapter resource: PowerShell installs it in isolated scratch layouts and Hugo resolves required i18n keys against actual mounted catalogues. Normal and missing-placeholder passes produce per-language evidence. The probe never edits the rendering module or enters the deployed artifact. Text availability, fallback and translation quality are different claims.

Prepare persists JSON/Markdown findings before throwing on blockers. Runtime wrapper readiness remains unknown until generated output has been checked. Missing evidence and report delivery failures do not become successful assessments.

`Write-GuideAssessmentSummary` appends schema-validated Markdown to Actions. `Publish-GuideAssessmentComment` is an append-only, commit-scoped GitHub adapter with PR-head checks and idempotency detection. It remains unwired to privileged automatic PR publication pending the trusted reporter boundary; report artifacts and Actions summaries are active. `-WhatIf` reads metadata without posting.

Artifact validation checks identity, configured routes, forbidden directories, JSON, tokens, duplicate Hugo output targets and size. Deployed HTTP/browser validation remains a separate stage.
