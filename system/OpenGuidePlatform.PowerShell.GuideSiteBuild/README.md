# Guide-site build and reporting adapters

Core owns publishing rules and structured assessments. This module owns guide-site preparation, Hugo execution, artifact validation and reporting. `Invoke-GuideSiteBuild` is the entry point used by the root build and installed guide-site launcher. The launcher restores its locked release, imports this module and passes the requested stage and target.

The shared workflow restores either the selected GitHub Release or the exact candidate ZIP produced by the platform build. All sample stages consume that candidate before publication. YAML contains action orchestration and PowerShell calls; build decisions and GitHub API operations live in PowerShell, with no authored JavaScript in the workflows.

`GitHubActions` adapts assessment delivery and deployment checks to GitHub. Reporting and deployment restore platform code independently from the selected package and treat site artifacts as data. `Publish-GuidePrepareAssessment` maintains the current commit-scoped PR report; `Confirm-GuideDeploymentData` checks the artifact inventory, hashes and identity before upload. These checks do not provide independent policy enforcement against changes to the selected platform itself.

Discovery recognises guide-root cascades with `list: never`, `render: never` and an exact `target.environment` of canary, preview or production. It confirms the exclusion through Hugo's source listing and obtains public paths from another configured environment. Descendant overrides remain subject to validation. An excluded guide needs a configured environment where its paths can be discovered; environment glob expressions and path-specific cascades are not interpreted as whole-guide exclusions. Set `publishResources: false` in the site's exclusion cascade when its bundled resources must also remain unpublished: validation still rejects excluded PDFs and resources that leak into the artifact.

`WrapperTranslations/probe.html` is a standalone diagnostic/test resource, never called by guide-site Prepare: PowerShell installs it in isolated scratch layouts and Hugo resolves required i18n keys against actual mounted catalogues. Normal and missing-placeholder passes produce per-language evidence. The probe never edits the rendering module or enters the deployed artifact. Text availability, fallback and translation quality are different claims.

Prepare persists JSON/Markdown findings before throwing on blockers. Runtime wrapper readiness remains unknown until generated output has been checked. Missing evidence and report delivery failures do not become successful assessments.

`Write-GuideAssessmentSummary` appends validated Markdown to Actions. The isolated reporting job in the shared workflow maintains the current PR assessment; detailed historical evidence remains in workflow artifacts.

Artifact validation checks identity, configured routes, forbidden directories, JSON, tokens, duplicate Hugo output targets and size. Deployed HTTP/browser validation remains a separate stage.


Inferred sites derive expected home JSON outputs from effective Hugo configuration and inspect configured JSON outputs emitted by Build. Explicit policies may also declare `wrapper.jsonIndexes`. Each entry names a `route` (such as `/translations.json`) and `requiredRoutes` that must appear in that index. Validate checks nested public URL fields against the artifact, rejects prohibited targets and compares language catalogues with the languages observed during Prepare. Results are included in the normal validation report; `json-index-validation.json` also holds local detail. This does not change Hugo output formats or enable an index.

Prepared inputs use one physical-file inventory even when guide and wrapper roots overlap. Publication evidence is still rejected after source drift.

## One delivery pipeline

The site calls the shared workflow once. Prepare calculates GitVersion using `.github/GitVersion.yml`: an empty prerelease label means production, `Preview` means preview, and other labels mean canary. PR builds select canary even when their source branch is a release branch. There is one Build, Validate, Deploy and Verify; they consume Prepare outputs and the same validated artifact.

Declare the `delivery` mapping in `.OpenGuidePlatform/settings.yaml` with `canary`, `preview` and `production` objects, each containing `url` and `environment`. `{pr}` is replaced by the PR number, or `canary` for a branch run without a PR; locally supply `-PullRequestNumber` to reproduce a PR destination. Production uses an empty environment; non-production must use a named environment. Prepare uses `hugo.<target>.yaml`. GitVersion 6 is installed or upgraded locally by `Dependencies`; .NET SDK is required. `Update` migrates old configuration to the v6 schema. Main preview versions advance on each commit; `+semver: minor` and `+semver: major` request larger increments.

`./build.ps1 -Target auto -PullRequestNumber 111 -OutputPath .processing/pr-111` reproduces PR preparation, build and validation locally. To use separate stages, retain this output path; later auto stages read the saved `delivery-context.json`. `-Target local` remains available for local Hugo configuration and Serve. Deployment remains explicit (`-Deploy`) locally.

Local and hosted builds use `settings.yaml` to select an exact OGP release or the latest eligible release within a major/minor family and OGP ring. The JSON installation record retains generated installed identities. Prepare records the resolved version and checksums; later stages reuse that package. Floating native dependencies are resolved through a generated Go workspace under the run's `.processing/` evidence, without editing tracked files. Site publishing rings remain GitVersion-derived and independent of the OGP ring. Existing installations without settings retain their exact installed pin until upgrade. Candidate ZIPs remain the prepublication transport for sample validation.


## Inferred site validation

Guide-site builds discover the source directory's guide roots, edition bundles, language suffixes and PDF resources. Prepare reads effective configuration and Hugo's non-rendering source list for permalink metadata, retaining the site's original content and layouts. It never renders a discovery site. The list includes drafts/future/expired pages; source expectations filter those using the selected ring configuration. Prepare checks the expected guide root, history and translations source pages for each active guide language. Build renders the site once. Validate checks independently expected routes and source PDF bytes at owning edition resource paths; Validate also follows internal links and checks their runtime fragments. The snapshot is retained under the selected `.processing/` output, never maintained in the repository.

The installed support files live under `.OpenGuidePlatform/`: `installation.json`, `Resolve-OpenGuidePlatform.ps1` and user-owned `settings.yaml`. Only the thin `build.ps1` entry point remains in the site root. Installation no longer requires `guide-site.policy.json`; `settings.yaml` owns `site.source`; the installation record stores generated installation state. Upgrade migrates the previous source path and delivery file transactionally.

Prepare requires a front matter alias such as `/my-guide/latest` on each language's latest published, non-draft edition (ordered by edition date). Hugo supplies the language prefix. Missing, duplicate, older-edition, draft or future-edition ownership blocks the build and names the source files to fix. Validate also checks that the alias route was generated.
Place the aliases block after descriptive front matter metadata; it must never be the first field.

Prepare reads explicitly required i18n keys from local and mounted YAML/JSON catalogues, including source text in the default-language fallback. This is source availability, not runtime interpolation or translation-quality evidence. Inferred installations do not maintain a required-key policy.

Required-key inspection currently supports ordinary directory/file mounts of YAML and JSON catalogues. Filtered mounts and TOML catalogues block with an explicit unsupported-evidence message; they are not silently treated as missing or complete.
