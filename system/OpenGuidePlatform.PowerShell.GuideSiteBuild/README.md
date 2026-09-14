# Guide-site build and reporting adapters

Core owns publishing rules and structured assessments. This module owns guide-site preparation, Hugo execution, artifact validation and reporting. `Invoke-GuideSiteBuild` is the entry point used by the root build and installed guide-site launcher. The launcher restores its locked release, imports this module and passes the requested stage and target.

The shared workflow restores either the selected GitHub Release or the exact candidate ZIP produced by the platform build. All sample stages consume that candidate before publication. YAML contains action orchestration and PowerShell calls; build decisions and GitHub API operations live in PowerShell, with no authored JavaScript in the workflows.

`GitHubActions` adapts assessment delivery and deployment checks to GitHub. Reporting and deployment restore platform code independently from the selected package and treat site artifacts as data. `Publish-GuidePrepareAssessment` maintains the current commit-scoped PR report; `Confirm-GuideDeploymentData` checks the artifact inventory, hashes and identity before upload. These checks do not provide independent policy enforcement against changes to the selected platform itself.

`WrapperTranslations/probe.html` is an adapter resource: PowerShell installs it in isolated scratch layouts and Hugo resolves required i18n keys against actual mounted catalogues. Normal and missing-placeholder passes produce per-language evidence. The probe never edits the rendering module or enters the deployed artifact. Text availability, fallback and translation quality are different claims.

Prepare persists JSON/Markdown findings before throwing on blockers. Runtime wrapper readiness remains unknown until generated output has been checked. Missing evidence and report delivery failures do not become successful assessments.

`Write-GuideAssessmentSummary` appends validated Markdown to Actions. The isolated reporting job in the shared workflow maintains the current PR assessment; detailed historical evidence remains in workflow artifacts.

Artifact validation checks identity, configured routes, forbidden directories, JSON, tokens, duplicate Hugo output targets and size. Deployed HTTP/browser validation remains a separate stage.


Declare enabled JSON outputs under `wrapper.jsonIndexes` in the site policy. Each entry names a `route` (such as `/translations.json`) and `requiredRoutes` that must appear in that index. Validate checks nested public URL fields against the artifact, rejects prohibited targets and compares language catalogues with the languages observed during Prepare. Results are included in the normal validation report; `json-index-validation.json` also holds local detail. This does not change Hugo output formats or enable an index.

Prepared inputs use one physical-file inventory even when guide and wrapper roots overlap. Publication evidence is still rejected after source drift.
