# Developing OpenGuidePlatform

These commands run in the **OpenGuidePlatform repository**. For an installed guide site, use the [README](../readme.md).

## Build and test

Install the tools listed in the README and Node.js (for isolated GitHub reporting adapter tests), then the platform test dependencies:

```powershell
./.build/Install-PlatformTestDependencies.ps1
./build.ps1 -Versions
./build.ps1 -Version 0.0.0-local
```

The platform build runs preparation, tests, packaging and package verification. It writes to a fresh directory under `.processing/platform/`; it does not publish a release or build the sample. Pester is a platform-development dependency, not an everyday guide-site requirement.

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

Prepare report is a separate delivery job beside Prepare so its comment-writing token is never given to guide-site build code. It downloads only the assessment data, posts the common Markdown report, and never checks out or executes candidate scripts. It runs for same-repository PRs even when Prepare fails; fork PRs retain Actions artifacts. Reports are immutable per commit/run/attempt, with duplicate and stale-head protection. A report is candidate evidence, not the independent E06 policy gate.

Required stage check names contain the site name and stage only; preview and production report the same checks. The target remains visible in assessment summaries and artifact names.

The sample directly calls the [shared guide-site workflow](../.github/workflows/guide-site-build.yaml). It receives the build artifact ZIP URL, SHA256, GitVersion version and source commit. The ZIP contains `OpenGuidePlatform.zip`, `release-manifest.json` and standalone `bootstrap.ps1`. Restoration validates both archive checksums and the expected identities before using the packaged tooling.

Publication depends on sample success and downloads the same artifact ID without rebuilding it. Publication runs only on pushes to main. PRs build and validate the candidate artifact and may deploy their sample preview, but never create a platform release. Manual workflow runs do not publish. Preview runs deploy only trusted changes to the sample preview; the manual production target validates output without production deployment.

Ordinary consumers can pass an explicit published release tag. Without a ZIP URL or tag, restoration resolves the unique published release matching the supplied platform commit. Missing or ambiguous releases fail.

A local source build is useful feedback, but does not establish that the complete GitHub publication sequence has succeeded. Review the Actions run before accepting a release change.

## Sample hosting

| Environment | Address |
|---|---|
| Shared preview | https://blue-field-06cea8c03-preview.westeurope.6.azurestaticapps.net/ |
| PR preview | `https://blue-field-06cea8c03-<number>.westeurope.6.azurestaticapps.net/` |
| Production destination | https://blue-field-06cea8c03.6.azurestaticapps.net/ |

These are configured destinations, not a claim that each environment is deployed. PR 35 uses [its own preview](https://blue-field-06cea8c03-35.westeurope.6.azurestaticapps.net/). The sample's production deployment is disabled. [PR cleanup](../.github/workflows/sample-close-pr.yaml) cancels the matching run and closes that PR's preview environment.

## Try the unmerged installer

Until the installer is available on `main`, run this from a prepared guide-site repository to evaluate the current implementation branch:

```powershell
irm https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/codex/open-guide-platform/bootstrap.ps1 | iex
```

It still downloads a published preview package. Changing the bootstrap source URL does not build or install arbitrary uncommitted platform code.

See the [execution plan](architecture/open-guide-platform-execution-plan.md) for remaining adoption work and acceptance evidence, and the [architecture proposal](architecture/open-guide-platform-proposal.md) for component responsibilities.