# OpenGuidePlatform

Shared guide rendering, publishing operations, validation and agent tooling for sites with one or more guides. Each guide site keeps its own content and bespoke wrapper.

## Two products, two workflows

| Workflow | Responsibility |
|---|---|
| `.github/workflows/main.yaml` — **Build & Release (OpenGuidePlatform)** | Build, test and package the platform, then publish and verify a GitHub Release containing the consumer assets. |
| `.github/workflows/sample-main.yaml` — **Build & Release (GuideSiteSample)** | Call the shared guide-site workflow with the sample policy and an exact platform release. It never builds or packages the platform. |
| `.github/workflows/guide-site-build.yaml` | Restore the released platform, then run separately named Prepare, Build, Validate, Deploy and Verify jobs for the requested site target. This is the consumer workflow, including for the sample. |

GitVersion, using `.github/GitVersion.yml`, determines the version. The source SHA is recorded separately as provenance. The sample waits up to ten minutes for the release matching its explicitly pinned platform commit; other consumers can provide an exact release tag. It fails if the release cannot be restored; it never falls back to a repository build. A platform run and the sample run must both pass for candidate acceptance. A preview release can exist while sample validation is pending or failed. These development versions are not stable releases.

The sample and platform workflows have independent runs in Actions. Platform source checks are not evidence of a successful consumer build.

## Prerequisites

Use PowerShell 7.4+, Hugo Extended 0.146+ and Go supporting the declared module toolchains. CI uses the configured HUGO_BUILD_VERSION (or latest) and Go >=1.24.5. Platform tests require Pester 5.7.1 and powershell-yaml 0.4.12:

```powershell
./.build/Install-PlatformTestDependencies.ps1
./build.ps1 -Versions
```

GitHub Release restoration also requires authenticated `gh` access to the public repository. PDF generation separately requires Pandoc, XeLaTeX and the appropriate fonts.

## Build the platform locally

```powershell
./build.ps1
```

This runs Prepare, Build, Package and local package Validate. It does **not** publish a release or build the sample. Output goes to a fresh directory under `.processing/platform/`.

Individual stages are available through `-Stage Prepare|Build|Package|Validate`. Use the same explicit `-OutputPath` for Package and Validate. Release publication is an explicit CI stage, never part of the bare local command.

The archive includes the named system components, runtime build entry points, licence and documentation. `release-manifest.json` records the version, source commit and archive SHA256. Package verification extracts into a fresh location and loads the distributed PowerShell modules.

## Build a guide site from a release

Use an exact release and its source commit. These are the same operations the shared workflow performs:

```powershell
./.build/Restore-OpenGuidePlatformRelease.ps1 -ReleaseTag 'v<GitVersion-SemVer>' -ExpectedCommit '<40-character-commit>' -OutputPath .processing/platform
./.processing/platform/build.ps1 -Product GuideSite -WorkspaceRoot $PWD -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target preview -Version '<GitVersion-SemVer>' -OutputPath .processing/sample-preview
```

Replace the placeholders with an actual published candidate. Restore verifies release, manifest and installed identities plus the package digest. Existing installation/build output is refused; choose a fresh directory.

A guide-site workflow in another repository calls `nkdAgility/OpenGuidePlatform/.github/workflows/guide-site-build.yaml@<platform-commit>`, passing its source ref, policy path, site name, platform release and matching platform commit. The sample uses the same interface. During platform development the sample selects the release by its pinned platform commit; adopted sites pin an explicitly selected release and matching commit.

## Develop the sample locally

For an unpublished local edit, explicitly select the source build tooling:

```powershell
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target preview
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target production
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Stage Serve
```

Serve runs Prepare, then starts Hugo's initial build and watch loop. Stop with Ctrl+C. Run a full guide-site build before committing. Local source testing does not substitute for the sample CI release-restoration check.

## Reports and current limits

Guide-site evidence includes `prepare/assessment.json`, `prepare/assessment.md`, `hugo.log`, `artifact-identity.json`, `artifact-validation.json` and the generated `site/`. Actions retains separate preview and production artifacts.

Prepare assesses the wrapper, guide editions, translations and declared downloads. It checks permanent production exclusions even during a preview build. Effective i18n evidence comes from isolated Hugo probes using the actual catalogues and module; resolved text does not prove translation quality. Expected failure tests have isolated summary destinations.

Validate checks declared wrapper routes, generated JSON, unresolved tokens, duplicate target paths, prohibited language directories, artifact size and identity. Build evidence is not browser or hosting approval. Deploy uploads only the validated artifact to an explicitly configured Azure Static Web App. Verify compares the served identity, required pages and PDFs against that artifact and checks forbidden language routes. The sample validates preview and production artifacts, then deploys only preview to the supplied Blue Field Static Web App (a PR-specific named environment) and verifies it. Its production deployment remains disabled. Trusted external enforcement and full adoption remain open work; this change does not modify deployed consumer sites.

The module keeps its historical identity `github.com/nkdAgility/HugoGuides/module` for now. The candidate build resolves the module from the verified package through an output-only configuration overlay. Canonical native module publication and the full coordinated adoption lock remain required before consumer adoption is declared complete. No Hugo rendering internals are refactored here.

## Repository responsibilities

| Location | Purpose |
|---|---|
| `build.ps1` | Human and CI stage entry point |
| `.build/` | Platform lifecycle and guide-site orchestration |
| `system/OpenGuidePlatform.Hugo.Guides/` | Existing shared Hugo rendering |
| `system/OpenGuidePlatform.PowerShell.Core/` | Guide publishing rules and operations |
| `system/OpenGuidePlatform.PowerShell.Build/` | External-tool, build and reporting adapters |
| `system/OpenGuidePlatform.AgentSkills/` | Shared publishing skills |
| `examples/reference-guide-site/` | Independent sample wrapper and guides |
| `tests/` | Platform regression tests |
| `docs/architecture/` | Approved plan, decisions and evidence |

Read [Core commands](system/OpenGuidePlatform.PowerShell.Core/README.md), [skill usage](system/OpenGuidePlatform.AgentSkills/USAGE.md), the [execution plan](docs/architecture/open-guide-platform-execution-plan.md) and [cross-consumer evidence](docs/architecture/baselines/2026-09-13-relocation/README.md).

Keep this README updated with commands, prerequisites, workflow responsibilities and report changes. Preserve supplied/protected PDFs and the deliberately structured multilingual Hugo module. Existing legacy download aliases remain consumer compatibility behavior; do not extend them to new languages.

The shared workflow accepts `target`, `deploy`, `deployment-environment` and the explicitly mapped `static-web-app-token` secret. Named preview environments are required for nonproduction deployment. Deploy rechecks artifact hashes immediately before the hosting action; no Hugo build runs in Deploy or Verify. Each stage retains its own evidence artifact. HTTP verification has bounded retries; unavailable or mismatching evidence fails verification.
The Azure-generated workflow is retained unchanged under `.github/workflow-reference/azure-static-web-apps-blue-field-06cea8c03.yml`; outside the workflows directory it cannot trigger a competing deployment.
Sample URLs follow the existing guide-site convention: production `https://blue-field-06cea8c03.6.azurestaticapps.net/`, preview `https://blue-field-06cea8c03-preview.westeurope.6.azurestaticapps.net/`, and PR `https://blue-field-06cea8c03-<number>.westeurope.6.azurestaticapps.net/`. The selected URL is passed into the generated Hugo overlay; Verify uses the actual URL returned by Azure.
`sample-close-pr.yaml` is the thin sample caller for shared `guide-site-close-pr.yaml`. Closing a same-repository PR cancels its in-flight sample run and deletes only its matching PR-number environment. Cleanup never builds or checks out PR code. The open PR is not closed merely to test cleanup.
Azure confirmed the PR 35 environment as `35`, at `https://blue-field-06cea8c03-35.westeurope.6.azurestaticapps.net/`. The shared sample uses this observed PR environment convention; existing consumers declare canary names, but those declarations are not evidence of the hosting URL.