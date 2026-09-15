# OpenGuidePlatform

Build and maintain guide websites with shared Hugo rendering, publishing tools, translation checks and agent skills. Your site keeps its own design, content and any number of guides.

**Current status: preview.** Installation and updates are available for evaluation on a branch. First adoption needs maintainer setup; stable adoption and independently enforced agent controls are not yet complete.

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
| Update the installed platform | `./build.ps1 Update -ring preview` |
| Preview an update's file changes | `./build.ps1 Update -ring preview -WhatIf` |

Build runs **Prepare → Build → Validate**. Prepare uses GitVersion to select canary, preview or production and reads destinations from `.OpenGuidePlatform/delivery.yaml`. Install dependencies first with `./build.ps1 Dependencies` (.NET SDK required); use `-PullRequestNumber 111` to reproduce a PR destination locally, or `-Target local` for local configuration. The shared workflow runs one chain through Deploy and Verify. OGP builds restore the release pinned in `.OpenGuidePlatform/installation.json`, locally and in GitHub Actions. `platform-ring` does not advance that pin. Install/update selects the release; publishing a newer OGP release does not change existing site builds. See [delivery configuration](system/OpenGuidePlatform.PowerShell.GuideSiteBuild/README.md#one-delivery-pipeline). Serve performs preparation and Hugo's initial build, then watches for changes; open the address printed in the terminal and press **Ctrl+C** to stop it. The installed `build.ps1` is a thin launcher: it restores your locked platform package and calls its PowerShell Build module. GitHub Actions uses that same module. Routine builds use your installed platform version and can restore it offline once cached. Run `./build.ps1 Update -ring preview` to adopt the latest compatible preview, or add `-PlatformRelease vX.Y.Z-Preview.N` to select a release. Updates run the target release’s adoption module and report conflicts before changing managed files.

To test another platform without changing your installation lock:

```powershell
./build.ps1 -PlatformSource Local -PlatformPath ../OpenGuidePlatform -Target preview
./build.ps1 -PlatformSource Preview -Target preview
./build.ps1 -PlatformSource Production -Target preview
./build.ps1 -PlatformPath ./candidate/OpenGuidePlatform-GuideSite.zip -Target preview
```

The installation record is the shared version pin. Change it through `./build.ps1 Update -ring preview` (or `-ring production`), review the coordinated changes and commit them. Do not edit the record or the Hugo dependency independently. The workflow definition's `uses: ...@version` selects workflow wiring, not a newer build package. The site ring still controls publishing exclusions and deployment, independently of the installed OGP version.

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

This runs Prepare → Build → Validate → Deploy → Verify. Deploy uploads the validated files without rebuilding and saves the returned URL in `deployment.json`. Verify checks the deployed identity, required routes and excluded content. A failed earlier stage stops the sequence. Production requires an explicit production target; preview deployment rejects production environment names.

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
