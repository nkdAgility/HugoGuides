# OpenGuidePlatform

**Publish guides, papers and articles in multiple languages and versions—with a front end designed for your audience.**

OpenGuidePlatform provides the shared publishing system beneath your site. Publish one document, a collection, or a growing library. Keep past editions available, manage translations independently, and offer web and PDF access to your publications.

Your site owns its front end: branding, navigation, page layouts and the surrounding experience. Use the shared Hugo modules within a bespoke site, or make your guides one part of a larger website. The platform does not prescribe a single site design.

It provides:

- **Multilingual, versioned publishing:** separate editions and translations, stable latest-edition links and publication rules.
- **Hugo rendering and PDF tooling:** shared publication components, downloadable documents and tools for generating declared PDFs.
- **One build process locally and in CI:** PowerShell preparation, build and validation, with deployment and verification support.
- **Actionable checks:** findings for missing content, broken links, downloads and publishing exclusions, reported in build output and pull requests.
- **Shared agent resources:** instructions and skills for contributors using Codex, Claude and GitHub Copilot.
- **Controlled updates:** select an exact release or allow updates within a major/minor version, with the same resolution locally and in CI.

Installation and updates support published preview and production releases. First adoption needs maintainer setup; independently enforced agent controls remain separate work.

## Before you start

Work from the root of your **guide-site repository**, using PowerShell 7.4 or newer. You need Git, [GitHub CLI](https://cli.github.com/), Hugo Extended 0.146 or newer, and Go 1.24.5 or newer (or the newer version required by your site's modules).

Sign in and install the currently required PowerShell YAML dependency:

```powershell
gh auth login
Install-Module powershell-yaml -MinimumVersion 0.4.12 -Scope CurrentUser
```

On Windows, enable **Developer Mode** or use an account with symbolic-link privileges, then run this before cloning:

```powershell
git config --global core.symlinks true
```

The platform uses symbolic links for its shared agent instructions. Linux and macOS normally need no additional setup. See [Windows troubleshooting](docs/using/first-adoption.md#windows-symbolic-links) for an existing clone.

**First installation?** Run from a guide-site repository with Hugo configuration in `site/hugo.yaml` (or supply `-SourcePath` for another Hugo directory). Prepare discovers guides, editions, languages, pages and PDF resources. There is no site policy inventory to author or maintain.

## Install or update

For first installation, run:

```powershell
irm https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/main/bootstrap.ps1 | iex
```

It selects the newest installable preview release and verifies the download. On `main` or `master`, it creates a review branch; otherwise it uses your current branch. It updates the native Hugo dependency to the same release and preserves your wrapper YAML formatting. Existing files that conflict with the installation are reported for review.

Once installed, update on your review branch with `./build.ps1 Update -ring preview`. The remote bootstrap command also supports updates. Bootstrap is not installed into your repository or shipped as a release asset.

Workflow callers are site-owned: configure their triggers, inputs and secrets without losing those settings on update. Install `gh extension install github/gh-actions-lock` first. OGP updates recognised caller release references and regenerates their Actions lockfile alongside the native dependency; ambiguous callers or locking failures stop the update. See [caller ownership and updates](docs/using/first-adoption.md#caller-ownership-and-updates).

Then check the changes and build both targets:

```powershell
git diff
./build.ps1 -Target preview
./build.ps1 -Target production
```

Review the results, commit your changes and open a pull request. Neither the installer nor these build commands publishes your site. Your maintainer configures preview and production deployment during first adoption.

New installer features become available after the change is merged and its release passes sample validation. See [platform development](docs/platform-development.md#installer-changes-before-publication) for prepublication testing.

## Everyday use

Once installed, run these commands from your guide-site repository:

| Task | Command |
|---|---|
| Install build dependencies | `./build.ps1 Dependencies` |
| Check and build the site locally | `./build.ps1` |
| Start the local site and watch for edits | `./build.ps1 -Stage Serve -Target local` |
| Check preview output | `./build.ps1 -Target preview` |
| Check production output | `./build.ps1 -Target production` |
| Check inputs without building pages | `./build.ps1 -Stage Prepare` |
| Update to the latest preview platform | `./build.ps1 Update -ring preview` |
| Update to the latest production platform | `./build.ps1 Update -ring production` |
| Preview an update's file changes | `./build.ps1 Update -ring preview -WhatIf` |

Build runs **Prepare → Build → Validate**. Prepare uses GitVersion to select the site's canary, preview or production ring and reads delivery destinations from `.OpenGuidePlatform/settings.yaml`. The shared workflow continues through Deploy and Verify. Install dependencies with `./build.ps1 Dependencies` (.NET SDK required); use `-PullRequestNumber 111` to reproduce a PR destination locally, or `-Target local` for local configuration. Serve prepares and builds before watching; press **Ctrl+C** to stop it.

## Platform settings and updates

`.OpenGuidePlatform/settings.yaml` is yours to edit. `.OpenGuidePlatform/installation.json` remains installer-managed; do not edit its generated release identities or checksums.

```yaml
platform:
  version: v1
  ring: production
site:
  source: site
delivery:
  canary:
    url: https://example-{pr}.azurestaticapps.net/
    environment: "{pr}"
  preview:
    url: https://example-preview.azurestaticapps.net/
    environment: preview
  production:
    url: https://example.org/
    environment: ""
```

Select an exact release, a minor family or a major family through the existing update command:

```powershell
./build.ps1 Update -ring production -PlatformRelease v1
./build.ps1 Update -ring production -PlatformRelease v1.2
./build.ps1 Update -ring production -PlatformRelease v1.2.3
./build.ps1 Update -ring preview -PlatformRelease v0
```

`v1` accepts `1.x.y` but never `2.0.0`; `v1.2` accepts patch releases within `1.2`; a complete version stays exact. A new build resolves the highest matching published version in the selected OGP ring. Prepare records the exact release and checksums, and later stages reuse it. Floating selection requires release access; exact installed releases can restore from cache offline. OGP publication does not trigger your site or open an update PR.

`platform.ring` selects OGP releases, independently of the site's deployment ring. Production sites using preview OGP receive a warning, not a deployment block. Changing the version selection also requires its corresponding shared-workflow reference; run `Update` after editing it directly, review and commit the coordinated changes. Settings, workflow triggers, inputs and secrets remain site-owned. Installed agent instructions and skills refresh during Update; builds use the selected package's matching PowerShell and Hugo components without overwriting tracked files.

**Upgrading an existing installation:** use the remote bootstrap command above once to obtain this update support. It migrates your existing source directory and `.OpenGuidePlatform/delivery.yaml` into settings, retains exact selection unless you request a version family, and keeps the JSON installation record. The old delivery file is removed only after a successful upgrade; failures roll back the migration. Existing settings and destination customizations are preserved. Thereafter use `./build.ps1 Update`; it honors your configured selection. An explicit ring-only update from an exact pin selects the latest release in that ring.

To resume local stages, pass the same `-OutputPath` used by Prepare. Build, Validate, Deploy and Verify reuse that run's prepared package rather than discovering a newer release.

To test another platform without changing your installation lock:

```powershell
./build.ps1 -PlatformSource Local -PlatformPath ../OpenGuidePlatform -Target preview
./build.ps1 -PlatformSource Preview -Target preview
./build.ps1 -PlatformSource Production -Target preview
./build.ps1 -PlatformPath ./candidate/OpenGuidePlatform-GuideSite.zip -Target preview
```

For an explicit diagnostic override, use `-PlatformRelease` locally or `platform-release` in the workflow. This does not update the installation; the selected release must still match the site's native Hugo dependency. Routine builds need neither override. Add `-PlatformRelease` to an Update command to install a specific release. The ZIP must have its `release-manifest.json` alongside it. Release overrides require an available compatible release and its coordinated Hugo dependency; use the installer to adopt a different dependency permanently. `Production` selects a non-prerelease platform package; it does not deploy the site. A release predating these module entry points cannot provide the new operations.

For translations, contributors, guide editions and PDFs, use the [publishing commands](system/OpenGuidePlatform.PowerShell.Core/README.md) or the [shared agent skills](system/OpenGuidePlatform.Agents.Integration/skills/USAGE.md). PDF generation additionally needs Pandoc, XeLaTeX and the fonts required by your guide. Supplied and protected PDFs are preserved.

Sites with declared JavaScript-created anchors also need Node.js 20 or newer and npm. Validate restores its browser tools into `.processing/` on first use and checks the built pages without contacting the live site. Later runs reuse that cache.

## Run the complete CI locally

The same PowerShell operations run locally and in CI. An ordinary build stops after Validate. To include Azure deployment and live verification, first install the deployment tools:

```powershell
./build.ps1 Dependencies -Deploy
```

Set `SWA_CLI_DEPLOYMENT_TOKEN` through your shell or CI secret mechanism. Commit your source changes, then run against your configured preview environment:

```powershell
./build.ps1 -Target preview -Deploy -DeploymentEnvironment my-preview -BaseUrl https://your-preview.example/ -DeploymentUrl https://your-preview.example/ -OutputPath .processing/preview-run
```

This runs Prepare → Build → Validate → Deploy → Verify. Deploy uploads the validated files without rebuilding and saves the provider URL as `url` and the supplied public URL as `publicUrl` in `deployment.json`. These URLs can differ when using a custom domain. Verify checks the identity at the provider URL and checks the deployed identity, required routes and excluded content at the build's configured public URL. A provider identity redirect is accepted only to that exact public identity URL. A failed earlier stage stops the sequence. Production requires an explicit production target; preview deployment rejects production environment names.

To run stages separately, use the same `-OutputPath` and `-Target` for every command: `Prepare`, `Build`, `Validate`, `Deploy`, then `Verify`. Supply the preview environment on Deploy. Verify can read the returned URL from the saved deployment record. Keep the source and selected platform version unchanged between stages.

A site with its own hosting can supply `-DeploymentAdapter ./path/to/deploy.ps1`. The script receives `ArtifactRoot`, `Target`, `Environment` and `ExpectedUrl`, uploads those files, and returns an object with an absolute HTTPS `Url`. It must throw on failure and must not rebuild or modify the artifact. This lets your own build compose the guide stages with other site concerns.

## When something fails

Read the finding and its suggested fix in the terminal or GitHub Actions job summary. For a PR opened from the same repository, Prepare maintains one current report per target with the assessed commit and workflow link. Earlier reports remain in workflow artifacts. Use the report for your current commit; a reporting failure is shown separately in the Prepare report job. Fork PRs retain their reports in Actions artifacts. Build reports are saved beneath `.processing/guidesite/` by default; a failed Prepare also prints its report paths.

| Problem | What to do |
|---|---|
| Hugo source not found | Supply the Hugo directory with `-SourcePath`; no policy file is required. |
| Installation or update conflicts | Review the listed files with your maintainer. Preserve local edits; the installer will not overwrite them. |
| Missing tool, PowerShell module or PDF font | Install the named dependency, then rerun the command. |
| Missing translation, file or download | Follow the report's suggested fix. Ask your maintainer if the absence is intentional. |
| Publication rule blocks a build | Resolve the finding with your maintainer; do not enable an excluded language to bypass it. |
| An output directory already exists | Omit `-OutputPath` to let the build choose a fresh directory. |

If you need help, include the command, finding and relevant report in a [GitHub issue](https://github.com/nkdAgility/OpenGuidePlatform/issues).

## Sample and further help

- [Sample preview](https://blue-field-06cea8c03-preview.westeurope.6.azurestaticapps.net/) — the shared preview environment when deployed. PR previews use their own URL, provided by the deployment comment.
- [First-time site setup](docs/using/first-adoption.md) — policy, existing files and deployment setup.
- [Platform development](docs/platform-development.md) — build this repository, run the sample locally and understand releases.
- [Workflow dependency locking](docs/platform-development.md#workflow-dependency-lockfile) — regenerate, verify and review Actions dependency locks when changing platform workflows.
- [Execution plan and current progress](docs/architecture/open-guide-platform-execution-plan.md).

## Versioning builds

Platform and guide-site builds use GitVersion 6. Run `./build.ps1 Dependencies` to install or upgrade the repository-local tool; global tools are not changed. Update migrates old GitVersion configuration while preserving site settings. Migration rewrites YAML formatting/comments; review the diff. All adopted sites should commit the migrated configuration.

Main builds increment the preview counter automatically, with Patch as the default next version. Use `+semver: patch` (or `fix`), `+semver: minor` (or `feature`), or `+semver: major` (or `breaking`) anywhere in a commit message to request a bump. These directives also work in merged commits. A stable release tag keeps its exact version and selects production; PRs remain canary.
