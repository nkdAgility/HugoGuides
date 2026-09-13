---
name: guide.transreconcile
description: "Audit guide translations and optionally create missing scaffolds without replacing populated translations."
---

Read [Core usage](../USAGE.md) and run `Get-GuideInventory` with the consumer root and policy. Default to reporting. Only an explicit repair request authorizes file creation.

For authorized missing guide scaffolds, use `New-GuideTranslationScaffold` with explicit guide, edition and language. It preserves existing files and requires production to be explicitly disabled for new scaffolds. A populated translation is not an accidental English copy merely because it has text. Do not delete its body.

Do not add lang front matter, prefix aliases automatically, reorder languages by global speaker counts, or enable production. Existing metadata, wrapper and i18n repairs require a specifically reviewed diff; report those gaps rather than claim this initial command repaired them. Supplied PDFs and declared fallbacks remain valid.

Rerun inventory and the consumer build after authorized edits. Report what was created, what was preserved, and what remains unresolved.

Use Get-GuideWrapperStatus with Languages from the effective site configuration for local wrapper YAML catalogue and required-file observations. Route and integration checks require observed build evidence and remain unknown without it. This does not evaluate Hugo module catalogue fallback, plural completeness or translation quality; preserve those distinctions in the report.
