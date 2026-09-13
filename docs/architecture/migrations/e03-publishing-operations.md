# E03 initial publishing operations and skills

Status: initial candidate implemented; E03 remains in progress.

The Core module groups commands under GuideInventory, TranslationReadiness, PublicationPolicy, AgentGovernance, ContributorManagement, EditionManagement and PdfPublishing. Filesystem and native-tool operations are separate from pure readiness and publication decisions. The seven existing dotted skill identities are retained in OpenGuidePlatform.AgentSkills. Their provenance manifest records original source paths and hashes; MIT attribution accompanies the extraction.

The candidates remove fixed guide counts and edition conventions, require an explicit workspace and policy, preserve existing destinations, and distinguish populated, empty, PDF-only and fallback content. Translation scaffolding requires production to be explicitly disabled, keeps aliases unchanged, and removes deprecated lang metadata only from the new scaffold. Edition snapshots remain drafts. No consumer skills, content or configuration were changed.

## Verification

- 43 local Pester tests passed, including protected writes, traversal/symlink refusal, publication exclusions, draft snapshots, existing-file preservation, explicit Persian PDF language and a native Pandoc failure that publishes no output.
- Seven skill metadata, relative-reference and exported-command checks passed.
- A real disposable Persian document generated successfully through Pandoc/XeLaTeX with installed Amiri. The one-page PDF was rendered and inspected: connected Persian text, right-aligned body and no clipping. No published PDF was regenerated. This smoke test is not a claim of visual parity for every consumer PDF.
- CI runs the same Core checks on Ubuntu 24.04 and Windows 2022. Remote results are recorded on the PR.

The bundled Python skill validator could not run because PyYAML was unavailable. Its hyphen-only name convention also conflicts with retaining the seven existing dotted identities. The PowerShell validator explicitly preserves those identities and checks metadata, links and referenced commands; it does not claim bundled-validator compliance.

## Work still required

See the Core README for current limitations. Full wrapper/i18n reconciliation, safe generated-PDF replacement/cache behavior remain E03 work. These commands are not yet ready for consumer installation. E04 builds stage orchestration and reports; E06 establishes independent enforcement; E07 distributes pinned candidates. Repository rename stays at E08 and Hugo internal refactoring stays at E14.
Follow-up: fallback chains now resolve only to declared, populated web translations; cycles and non-web targets remain unavailable. Snapshot writes use a private sibling staging directory and publish by rename. Regression tests cover copy failure cleanup/retry and a concurrent destination, which is preserved. Abrupt termination may leave staging/lock evidence requiring inspection; automatic crash recovery is not claimed.

Contributor follow-up: source inspection found both YAML extensions and the reviewer role in Scrum. The shared commands now preserve these conventions. Reviewed single-record updates require the source hash, validate collection/record scope and apply exact candidate text through staged replacement. Nine new tests cover preserved comments and other records, stale input, concurrent observed edits, protected paths, filename ambiguity, WhatIf and failed staging. No consumer data was modified. The cooperative lock is not a security boundary against editors ignoring it.
