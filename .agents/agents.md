# OpenGuidePlatform engineering instructions

Use the root PowerShell entry point for builds and validation.

- Platform changes: run `./build.ps1 -Version 0.0.0-local`. This tests and packages; it does not publish.
- Sample content, configuration or template changes: run `./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target preview` and repeat with `-Target production`.
- Shared Hugo changes require both sample targets as well as platform checks.
- Require exit code 0 with no ERROR lines before committing. Warnings must be understood.
- Use `./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Stage Serve` for the sample development server.
- CI and local work use the same stages. Direct Hugo commands are diagnostics, not the acceptance build.

Preserve Hugo module internals and deliberate multilingual guide behavior. Internal refactoring is deferred until all consumers have adopted and been verified.
Each guide site owns its bespoke wrapper and any number of guides. Never infer a fixed guide count.
Never enable Minionese in production. Preserve protected/source PDFs; do not regenerate supplied files.
Hugo front matter must not contain lang; Pandoc receives language metadata separately.

Questions request answers, not edits. Prefer good engineering over shortcuts. Use action version tags with only necessary version restrictions.

## GitHub Actions dependency locking

Actions policies include a `Require lockfile` workflow execution protection. It requires dependency locking; it does not freeze workflow YAML or approve workflow changes. Workflows can be edited and their lockfile regenerated together. Someone able to change both can introduce different dependencies; locking prevents upstream moving tags from silently changing the locked action code.

- When onboarding workflows or changing their `uses` dependencies, run the official `gh actions-lock` extension and review the workflow changes together with `.github/workflows/actions.lock`. Install the extension with `gh extension install github/gh-actions-lock` if needed.
- A normal `gh actions-lock` run preserves existing locks for moving references. Use `gh actions-lock --relock` only when intentionally updating those dependencies, and review the resulting dependency changes.
- Commit related workflow and lockfile changes together. Verify affected workflows, including reusable calls, and check for skipped or unsupported onboarding before claiming lockfile coverage.
- Do not infer that the repository has enabled `Require lockfile` merely because this guidance exists. Verify the live policy when its enforcement matters. The tooling is in technical preview; check current official documentation before relying on its format or limitations: https://github.com/github/gh-actions-lock.

## Workflow implementation

Keep workflow YAML thin: action wiring and PowerShell entry-point calls only. Do not author JavaScript in pipelines. Guide-site launchers restore the selected release and call its PowerShell Build module; keep build logic in the distributed module.
Work on a review branch, commit verified changes and keep preview evidence distinct from production approval.
Do not change or deploy consumer sites as a side effect of platform work.
Root AGENTS.md and CLAUDE.md are symbolic links to this canonical file. Keep the links; edit only this file. Windows checkouts require symbolic link support and git core.symlinks=true. Maintain human README instructions whenever commands change.
