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

## One delivery pipeline

The site calls the shared workflow once. Prepare calculates GitVersion using `.github/GitVersion.yml`: an empty prerelease label means production, `Preview` means preview, and other labels mean canary. PR builds select canary even when their source branch is a release branch. There is one Build, Validate, Deploy and Verify; they consume Prepare outputs and the same validated artifact.

Declare `.OpenGuidePlatform/delivery.yaml` in the site repository with `canary`, `preview` and `production` objects, each containing `url` and `environment`. `{pr}` is replaced by the PR number, or `canary` for a branch run without a PR; locally supply `-PullRequestNumber` to reproduce a PR destination. Production uses an empty environment; non-production must use a named environment. Prepare uses `hugo.<target>.yaml`. GitVersion 5 is installed by `Dependencies` because the existing repository configuration uses that version's schema; .NET SDK is required.

`./build.ps1 -Target auto -PullRequestNumber 111 -OutputPath .processing/pr-111` reproduces PR preparation, build and validation locally. To use separate stages, retain this output path; later auto stages read the saved `delivery-context.json`. `-Target local` remains available for local Hugo configuration and Serve. Deployment remains explicit (`-Deploy`) locally.

The workflow's optional `platform-ring` defaults to `production`. Omit `platform-release` to select the newest installable release in that ring, or supply a tag explicitly. Preview adoption sets `platform-ring: preview`. There is no `platform-commit` or `site-name` input. Prepare records verified release provenance internally and later stages restore that exact release, never another latest lookup. Candidate package URL, digest and version remain the prepublication transport for the platform's sample validation.


## Inferred site validation

Guide-site builds discover the source directory's guide roots, edition bundles, language suffixes and PDF resources. Hugo supplies effective languages and public URLs, including custom permalinks and resource paths. Prepare checks the expected guide root, history and translations source pages for each active guide language. Build validates the discovered routes and PDF bytes; Validate also follows internal links and checks their runtime fragments. The snapshot is retained under the selected `.processing/` output, never maintained in the repository.

The installed support files live under `.OpenGuidePlatform/`: `installation.json`, `Resolve-OpenGuidePlatform.ps1` and the optional `delivery.yaml`. Only the thin `build.ps1` entry point remains in the site root. Installation no longer requires `guide-site.policy.json`; the installation record stores the Hugo `sourcePath`.

Prepare requires a front matter alias such as `/my-guide/latest` on each language's latest published, non-draft edition (ordered by edition date). Hugo supplies the language prefix. Missing, duplicate, older-edition, draft or future-edition ownership blocks the build and names the source files to fix. Validate also checks that the alias route was generated.
Place the aliases block after descriptive front matter metadata; it must never be the first field.
