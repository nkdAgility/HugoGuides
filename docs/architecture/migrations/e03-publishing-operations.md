# E03 initial publishing operations and skills

Status: wrapper publishing and shared Prepare readiness are now implemented; final acceptance follows the reconciled checklist and current validation evidence below.

The Core module groups commands under GuideInventory, TranslationReadiness, PublicationPolicy, AgentGovernance, ContributorManagement, EditionManagement and PdfPublishing. Filesystem and native-tool operations are separate from pure readiness and publication decisions. The seven existing dotted skill identities are retained in OpenGuidePlatform.AgentSkills. Their provenance manifest records original source paths and hashes; MIT attribution accompanies the extraction.

The candidates remove fixed guide counts and edition conventions, require an explicit workspace and policy, preserve existing destinations, and distinguish populated, empty, PDF-only and fallback content. Translation scaffolding requires production to be explicitly disabled, keeps aliases unchanged, and removes deprecated lang metadata only from the new scaffold. Edition snapshots remain drafts. No consumer skills, content or configuration were changed.

## Verification

- 54 local Pester tests passed, including protected writes, traversal/symlink refusal, publication exclusions, draft snapshots, existing-file preservation, explicit Persian PDF language and a native Pandoc failure that publishes no output.
- Seven skill metadata, relative-reference and exported-command checks passed.
- A real disposable Persian document generated successfully through Pandoc/XeLaTeX with installed Amiri. The one-page PDF was rendered and inspected: connected Persian text, right-aligned body and no clipping. No published PDF was regenerated. This smoke test is not a claim of visual parity for every consumer PDF.
- CI runs the same Core checks on Ubuntu 24.04 and Windows 2022. Remote results are recorded on the PR.

The bundled Python skill validator could not run because PyYAML was unavailable. Its hyphen-only name convention also conflicts with retaining the seven existing dotted identities. The PowerShell validator explicitly preserves those identities and checks metadata, links and referenced commands; it does not claim bundled-validator compliance.

## Work still required

See the Core README for current limitations. Full wrapper/i18n reconciliation, safe generated-PDF replacement/cache behavior remain E03 work. These commands are not yet ready for consumer installation. E04 builds stage orchestration and reports; E06 establishes independent enforcement; E07 distributes pinned candidates. Repository rename stays at E08 and Hugo internal refactoring stays at E14.
Follow-up: fallback chains now resolve only to declared, populated web translations; cycles and non-web targets remain unavailable. Snapshot writes use a private sibling staging directory and publish by rename. Regression tests cover copy failure cleanup/retry and a concurrent destination, which is preserved. Abrupt termination may leave staging/lock evidence requiring inspection; automatic crash recovery is not claimed.

Contributor follow-up: source inspection found both YAML extensions and the reviewer role in Scrum. The shared commands now preserve these conventions. Reviewed single-record updates require the source hash, validate collection/record scope and apply exact candidate text through staged replacement. Nine new tests cover preserved comments and other records, stale input, concurrent observed edits, protected paths, filename ambiguity, WhatIf and failed staging. No consumer data was modified. The cooperative lock is not a security boundary against editors ignoring it.

PDF/wrapper follow-up: reviewed generated-PDF replacement and conservative cache evidence checks are implemented. Six PDF tests cover prior-output preservation and cache invalidation; five wrapper tests cover Persian, numeric regions, empty/missing/duplicate YAML keys and absent route/integration evidence. Real Persian replacement succeeded with installed Amiri and was rendered/inspected with connected glyphs, RTL body alignment and no clipping. MiKTeX reported its existing update-check warning. No consumer PDF changed. Effective Hugo catalogue fallback, plural completeness and automatic content repair are not claimed; these require build observations and reviewed consumer conventions.

## Reconciled wrapper and readiness completion

The earlier remaining-work descriptions above are historical. Reviewed generated-PDF replacement/cache validation and effective Hugo fallback observation were subsequently implemented. Set-GuideWrapperTranslation now supports explicit wrapper Markdown/catalogue creation and reviewed replacement, as well as selected-language configuration edits with production disabled for new languages. Regression coverage includes Persian, numeric regions, preserved populated content, stale hashes, unrelated configuration changes, protected/guide paths, legacy aliases, WhatIf and failed staging.

Translation skills now obtain readiness from the same root Prepare assessment as CI and use local catalogue inspection only as an additional diagnostic. Core/assessment tests verify effective fallback survives report serialization without being misreported as a missing local translation. The real Hugo probe covers actual module catalogues and fallback.

Build-adapter PDF receipt collection is E04, external authority is E06, and real consumer adoption is E09–E11. None is an additional E03 completion requirement. Native publishing, translation quality and complete plural-form verification are not claimed by these operations.