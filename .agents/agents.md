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
Keep workflow YAML thin: action wiring and PowerShell entry-point calls only. Do not author JavaScript in pipelines. Guide-site launchers restore the selected release and call its PowerShell Build module; keep build logic in the distributed module.
Work on a review branch, commit verified changes and keep preview evidence distinct from production approval.
Do not change or deploy consumer sites as a side effect of platform work.
Root AGENTS.md and CLAUDE.md are symbolic links to this canonical file. Keep the links; edit only this file. Windows checkouts require symbolic link support and git core.symlinks=true. Maintain human README instructions whenever commands change.
