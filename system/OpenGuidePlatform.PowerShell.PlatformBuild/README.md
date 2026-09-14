# OpenGuidePlatform platform build

This module owns the platform repository build: tool checks, tests, packaging, candidate-sample acceptance and preview publication. It ships in the same package and version as `OpenGuidePlatform.PowerShell.GuideSiteBuild`, which owns composable guide-site stages. The consumer module does not depend on this module.

Run `./build.ps1 -Version 0.0.0-local` from the platform checkout. All runs tests, packages and verifies the distribution, then starts fresh PowerShell processes to build and validate the sample in preview and production using the exact ZIP produced. It does not deploy or publish. Use `-Stage Sample -OutputPath <existing-package-output>` to repeat candidate acceptance independently. `-Stage Release` is explicit and preserves coordinated platform/native-module tag publication.

`Invoke-PlatformBuild` accepts WorkspaceRoot, Stage, OutputPath and Version explicitly. `Invoke-PlatformBuildOperation` exposes individual platform operations to existing thin `.build/` entry points. Repository identity for release publication is an explicit parameter, independent of the CI runner.

Packaging includes module implementations. Platform tests and the sample are inputs from WorkspaceRoot, not embedded fixtures in the distribution. Actual Azure upload still belongs to the existing workflow adapter; cross-provider deployment and macOS/TeamCity/Azure Pipelines acceptance remain separate gaps, not claims made by this module split.

## Failure explanations

Failing platform checks should throw `New-PlatformBuildFailure -Why <plain-language cause> -HowToFix <concrete repair>`. The test reporter retains those fields in local output, `.processing/platform-tests/<run>/summary.md`, machine-readable findings and the Actions summary/annotation. It handles test, setup and discovery failures. Unclassified exceptions are identified as undiagnosed and retain technical detail; the reporter must never invent a repair from an unfamiliar exception.

The workflow validator explains malformed workflow input and inline-script violations at their source. The Node deprecation notice emitted by third-party Actions is separate from a failed platform check.
