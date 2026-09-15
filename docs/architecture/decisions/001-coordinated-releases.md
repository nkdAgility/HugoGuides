# ADR 001 — Coordinated platform releases

Status: implementation decision for E01; publication remains gated by E07/E08.

Hugo modules use Go module tags, workflows use version tags with separately recorded source provenance, and PowerShell/skills/controls use package assets. Independent updates can produce an untested combination.

Publish one coordinated release manifest/lock containing each exact identity, source commit, package digest and toolchain. Preview and stable are release channels, not mutable version aliases. Existing tags remain unchanged. Use release-specific caches and atomically propose a lock, Hugo pin, workflow version tag and source provenance and generated-adapter update together.

This gives each consumer a reviewable update unit while retaining native distribution mechanisms. Packaging, clean-cache resolution and source/digest coherence are acceptance tests in E07; a structurally valid lock is not enough.

## Approved version-selection extension — 15 September 2026

The settings and upgrade work in PR #46 extends the exact-only decision above. Users own `.OpenGuidePlatform/settings.yaml`: platform version selection and release ring, Hugo source directory, and delivery destinations. `.OpenGuidePlatform/installation.json` stays generated JSON containing the exact installed identities and checksums.

An exact version remains fixed. `v1` or `v1.2` selects the highest published version within that family and the configured OGP ring. A build resolves once and preserves exact package/native-module evidence for every later stage, locally and in CI. The site deployment ring remains independently determined by GitVersion. Floating native resolution uses generated Go workspace files in `.processing/`; ordinary builds do not update tracked dependencies or agent files.

Exact release tags remain immutable. Major/minor shared-workflow aliases are intentionally movable (`v1`, `v1.2`, `v1-preview`, `v1.2-preview`), published with concurrency checks and without downgrading a newer alias. These aliases do not trigger platform publication. Publishing OGP never opens a consumer update PR or triggers a consumer build; consumer version tags trigger their own site pipeline.

Install/Update coordinates settings, native dependencies, workflow references, generated adapters and installed agent resources in one transaction. Upgrades migrate existing delivery YAML and source settings, preserve destinations, remove the old delivery file only on success and restore prior files on failure. Changing only the update ring preserves an existing major/minor boundary. Explicit package updates record that package's exact selection.
