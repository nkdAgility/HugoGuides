# Developing OpenGuidePlatform

These commands run in the **OpenGuidePlatform repository**. For an installed guide site, use the [README](../readme.md).

## Build and test

Install the tools listed in the README and Node.js 20 or newer and npm (for real browser validation tests), then the platform test dependencies:

```powershell
./build.ps1 Dependencies
./build.ps1 -Versions
./build.ps1 -Version 0.0.0-local
```

Without a version override, the platform calculates GitVersion using the same module operation as Actions. The repository currently uses GitVersion 5 configuration, so Dependencies installs a compatible 5.x tool beneath `.processing/tools/` without changing a global GitVersion installation. `-Version` remains an explicit override.

The platform build runs preparation, tests, packaging and package verification. It writes to a fresh directory under `.processing/platform/`, then builds and validates the sample in preview and production from the exact package ZIP it produced. It does not publish a release or deploy the sample by default; the opt-in commands below add those operations. Pester is a platform-development dependency, not an everyday guide-site requirement.

## Complete execution and publication

`./build.ps1` runs version/preparation, tests, package validation and both sample targets. It does not publish or deploy by default. To additionally deploy and verify the sample preview, configure `SWA_CLI_DEPLOYMENT_TOKEN`, run `./build.ps1 Dependencies -DeploySample`, then:

```powershell
./build.ps1 -DeploySample -DeploymentEnvironment my-preview -DeploymentUrl https://your-preview.example/
```

The sample uses the exact candidate GuideSite ZIP, its returned hosting URL and one evidence directory throughout. A consumer hosting script can be selected with `-DeploymentAdapter`.

Add `-Publish` only when deliberately publishing the platform after successful sample deployment and live verification. Publication uploads the tested packages, then downloads and verifies both published packages against the source identity. GitHub authentication is required for release operations. For separate jobs, `Package`, `Sample`, `Release` and `Validate -ReleaseTag` remain independently callable; the orchestrator must preserve their dependency order and exact artifact identity, as main.yaml does.

The platform's source checkout is the input being built and tested. Runtime build dependencies come from the selected module distribution; packaging still reads the source components to be packaged. Core build operations do not require GitHub environment variables. Workflow adapters own Actions outputs and PR delivery; release retrieval/publication deliberately uses GitHub. Azure Pipelines and TeamCity need only invoke the PowerShell entry points and provide paths, credentials and options. Dedicated provider verification was explicitly excluded from this change.

The built-in hosting adapter follows the [Azure Static Web Apps CLI deployment contract](https://azure.github.io/static-web-apps-cli/docs/cli/swa-deploy/). It runs outside the source directory, passes credentials through the environment, strips GitHub context from the child process, and requires a confirmed HTTPS URL rather than accepting exit code zero alone.

## Build module ownership

`OpenGuidePlatform.PowerShell.PlatformBuild` owns platform engineering. `OpenGuidePlatform.PowerShell.GuideSiteBuild` owns guide-site stages and remains independently importable. They ship as separate GuideSite and PlatformBuild ZIP assets in one coordinated release. Root scripts dispatch to the selected module; existing `.build/` build/test/package entry points forward to PlatformBuild.

Both root build entry points accept `-PlatformSource Local|Preview|Production|Path`, `-PlatformRelease <tag>` and `-PlatformPath <directory-or-zip>`. Platform checkouts default to their local module. Installed consumers default to their installation lock. An explicit override does not change that lock. Preview/Production without a tag select the latest eligible release once at startup; Production means a non-prerelease platform package, independently of the site's `-Target`.

A path points to a platform checkout, a restored platform directory, or `OpenGuidePlatform-GuideSite.zip` alongside its `release-manifest.json`. ZIP bytes are verified and extracted into a fresh workspace directory. The shared loader verifies selected packages before importing module code. Platform engineering also restores `OpenGuidePlatform-PlatformBuild.zip`, which depends on the exact GuideSite package from the same release. Both ZIPs and their manifest must be available when using an explicit ZIP path for a platform build.

For a consumer-owned build, import the selected Build module and invoke its stages around the consumer's other operations. PlatformBuild uses the newly built package for sample acceptance; consumers do not need PlatformBuild or the platform test dependencies.

## Run the sample

```powershell
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target preview
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target production
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Stage Serve
```

Serve prints the local address. Stop it with Ctrl+C. Shared Hugo changes require both sample targets and the platform checks. Preserve the intentionally structured multilingual behaviour; internal refactoring remains the later execution-plan stage.

## CI and releases

[main.yaml](../.github/workflows/main.yaml) runs:

**Build and package OpenGuidePlatform → sample Prepare → Build → Validate → Deploy → Verify → Publish OpenGuidePlatform GitHub Release**

Prepare report is a separate delivery job beside Prepare so its comment-writing token is never given to guide-site build code. It restores the selected platform package independently, downloads assessment data and calls the packaged PowerShell reporting adapter. It does not execute code supplied in the guide-site artifacts. The selected platform itself remains within the deferred E06/E08 trust boundary. It runs for same-repository PRs even when Prepare fails; fork PRs retain Actions artifacts. One comment per target shows the current assessment and its source commit, with duplicate and stale-head protection. Historical reports remain in workflow artifacts. A report is candidate evidence, not the independent E06 policy gate.

The Prepare report's Guide status section lists only warnings and blockers with a problem and remedy. Healthy guide editions/translations are omitted; PDF-only translations do not require a web body. A missing required PDF remains a finding. The complete observed inventory and informational findings remain in assessment.json. Human summaries show actionable findings, a compact module-current confirmation, and a short success message when validation passes. Restore provenance remains in job logs and platform-resolution.json rather than repeated summary blocks. Artifact validation remains distinct from deployment and live verification.

The shared workflow exposes Prepare, Build, Validate, Deploy and Verify; preview and production use the same stages. The target remains visible in assessment summaries and artifact names.

The sample directly calls the [shared guide-site workflow](../.github/workflows/guide-site-build.yaml). It receives the build artifact ZIP URL, SHA256, GitVersion version and source commit. The artifact ZIP contains `OpenGuidePlatform-GuideSite.zip`, `OpenGuidePlatform-PlatformBuild.zip` and `release-manifest.json`. The sample restores only the GuideSite package. Bootstrap is source-only infrastructure fetched from `main`; it is neither a release asset nor an installed file. Restoration validates both archive checksums and the expected identities before using the packaged tooling.

Publication depends on sample success and downloads the same artifact ID without rebuilding it. Publication runs only on pushes to main. PRs build and validate the candidate artifact and may deploy their sample preview, but never create a platform release. Manual workflow runs do not publish. Preview runs deploy only trusted changes to the sample preview; the manual production target validates output without production deployment.

Installed guide-site `build.ps1` restores the locked release, imports `OpenGuidePlatform.PowerShell.GuideSiteBuild` and calls `Invoke-GuideSiteBuild`. The platform root build delegates guide-site stages to the same module. In CI, YAML contains action wiring and single PowerShell calls; package selection, build decisions, PR reporting and deployment validation are implemented in scripts. The standalone restore script must validate the download before importing any package code.

Reporting and deployment independently restore the selected package rather than executing code from a guide-site artifact. Preview cleanup binds Azure's environment directly to the closed PR number. Browser validation still executes browser code to inspect site behavior; it is not pipeline orchestration.

Ordinary consumers can pass an explicit published release tag. Without a ZIP URL or tag, restoration resolves the unique published release matching the supplied platform commit. Missing or ambiguous releases fail.

A local source build is useful feedback, but does not establish that the complete GitHub publication sequence has succeeded. Review the Actions run before accepting a release change.

## Workflow dependency lockfile

This repository uses GitHub's Actions dependency lockfile at `.github/workflows/actions.lock`. It records exact commits and repository identities for external actions while workflow YAML retains readable version tags. It does not freeze workflow edits or approve dependencies: review workflow and lockfile changes together.

From the OpenGuidePlatform repository root, install the official extension once and regenerate after adding, changing or removing workflow dependencies:

```powershell
gh extension install github/gh-actions-lock
gh actions-lock --no-narrow
gh actions-lock --verify
git diff -- .github/workflows
```

`--no-narrow` preserves our major-version tag convention. Normal regeneration keeps existing locks for moving tags. To deliberately refresh those dependencies, run `gh actions-lock --relock --no-narrow`, verify, and review the new commits before committing. Do not hand-edit the generated lockfile or automatically accept suspicious moved/unreachable pins.

For an offline coverage check, run `gh actions-lock --verify-local`. Full `--verify` checks upstream pins and requires GitHub access. Commit generated workflow headers and the lockfile together. The initial lockfile was generated with extension v0.1.6 (format v0.0.2); this is technical-preview tooling, so consult the [official documentation](https://github.com/github/gh-actions-lock) when upgrading it.

All four workflows are scanned. The generator records the three workflows with external dependencies; `sample-close-pr.yaml` only calls the local `guide-site-close-pr.yaml`, whose Azure action is locked. Local reusable calls retain their existing syntax. Successful CLI verification is local evidence, not proof of GitHub runtime enforcement or reusable-workflow execution.

Repository administrators can separately enable **Settings → Actions → Policies → Require lockfile**. Adding these files does not enable that setting. Evaluate the policy and verify PR, manual, merge-queue and cleanup runs before enforcing it. Consumer repositories and their policies are managed separately.

## Sample hosting

| Environment | Address |
|---|---|
| Shared preview | https://blue-field-06cea8c03-preview.westeurope.6.azurestaticapps.net/ |
| PR preview | `https://blue-field-06cea8c03-<number>.westeurope.6.azurestaticapps.net/` |
| Production destination | https://blue-field-06cea8c03.6.azurestaticapps.net/ |

These are configured destinations, not a claim that each environment is deployed. PR 35 uses [its own preview](https://blue-field-06cea8c03-35.westeurope.6.azurestaticapps.net/). The sample's production deployment is disabled. [PR cleanup](../.github/workflows/sample-close-pr.yaml) cancels the matching run and closes that PR's preview environment.

## Installer changes before publication

Bootstrap fetches the shared loader from `main` and selects a compatible published release. Until a change is merged and a release passes sample validation, the public install command continues to use the published system. The platform tests exercise first installation, local self-update, conflict handling and cached builds against candidate fixture packages before publication.

## Distribution contract

Each release has one version and source commit. `release-manifest.json` schema 2 lists each package's filename, version, SHA256 and component inventory. `OpenGuidePlatform-GuideSite.zip` contains consumer build, adoption, Core, agent controls/integration and candidate Hugo resources. `OpenGuidePlatform-PlatformBuild.zip` contains platform engineering and declares its dependency on that exact GuideSite version and checksum. Guide-site builds do not restore PlatformBuild.

Bootstrap remains a remote source entry point. Installation and migration decisions live in the released GuideSiteAdoption module. The installed build launcher and shared loader support `./build.ps1 Update -ring preview` without fetching bootstrap or loader source from `main`. `-WhatIf` previews managed changes; `-PlatformRelease` selects an exact release. Ordinary builds never update the installation lock.

Updating an older installation removes its managed `bootstrap.ps1` only if its recorded checksum still matches. A locally edited bootstrap blocks the update with a conflict, and failed installation writes restore the retired file. Unmanaged files are preserved. Existing immutable releases are not modified; the new loader selects releases containing the new GuideSite asset. Stable adoption remains the separately tracked acceptance gate.

## Version-driven publication

GitVersion supplies the version for both branch and tag builds. A prerelease suffix produces a preview GitHub Release; a stable version produces a normal GitHub Release. The same publisher handles both and creates the matching Hugo subdirectory tag. The version determines the release channel, independently of the triggering ref.

The platform workflow runs for main branch pushes, root version tags such as `v0.5.3`, PRs and manual dispatch. PR, merge-group and manual-dispatch runs validate only. Eligible publication always waits for Build and the sample stages to succeed. Hugo subdirectory tags do not trigger another platform build. Existing tags are not moved by this change.
