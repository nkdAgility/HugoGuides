# Guide-site build and reporting adapters

Core owns publishing rules and structured assessments. This component owns Hugo configuration/probe execution, artifact validation and report delivery. Root `build.ps1 -Product GuideSite` orchestrates these operations through `system/OpenGuidePlatform.PowerShell.Build/GuideSiteBuild/Build-GuideSite.ps1` and `system/OpenGuidePlatform.PowerShell.Build/GuideSiteBuild/Prepare-GuideSite.ps1`.

The shared guide-site workflow restores an immutable GitHub Release before invoking its distributed build entry point. The sample has no separate packaging or source-build path in CI. See the root README for the platform/consumer workflow boundary and local commands.

`WrapperTranslations/probe.html` is an adapter resource: PowerShell installs it in isolated scratch layouts and Hugo resolves required i18n keys against actual mounted catalogues. Normal and missing-placeholder passes produce per-language evidence. The probe never edits the rendering module or enters the deployed artifact. Text availability, fallback and translation quality are different claims.

Prepare persists JSON/Markdown findings before throwing on blockers. Runtime wrapper readiness remains unknown until generated output has been checked. Missing evidence and report delivery failures do not become successful assessments.

`Write-GuideAssessmentSummary` appends validated Markdown to Actions. The isolated reporting job in the shared workflow maintains the current PR assessment; detailed historical evidence remains in workflow artifacts.

Artifact validation checks identity, configured routes, forbidden directories, JSON, tokens, duplicate Hugo output targets and size. Deployed HTTP/browser validation remains a separate stage.


Declare enabled JSON outputs under `wrapper.jsonIndexes` in the site policy. Each entry names a `route` (such as `/translations.json`) and `requiredRoutes` that must appear in that index. Validate checks nested public URL fields against the artifact, rejects prohibited targets and compares language catalogues with the languages observed during Prepare. Results are included in the normal validation report; `json-index-validation.json` also holds local detail. This does not change Hugo output formats or enable an index.

Prepared inputs use one physical-file inventory even when guide and wrapper roots overlap. Publication evidence is still rejected after source drift.
