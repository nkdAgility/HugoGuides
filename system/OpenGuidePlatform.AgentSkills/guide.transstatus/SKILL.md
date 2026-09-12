---
name: guide.transstatus
description: "Report declared guide translation states and missing resources without changing files."
---

Read [Core usage](../USAGE.md), load the consumer policy and run `Get-GuideInventory -WorkspaceRoot $WorkspaceRoot -Policy $policy`.

Report wrapper files separately from every guide, edition and language. Filter the returned inventory if the user selected a language or guide; do not hard-code the current sites' guide counts or names. Show declared intent, observed body state, downloads and findings. A populated body is not proof of translation quality. PDF-only and source-language fallback are legitimate declared states.

This skill is read-only. Do not repair aliases, reorder languages by speaker counts, enable publication or rewrite existing content. Wrapper routes/i18n keys in this initial inventory are declarations, not completed runtime validation; say when a check is still unavailable.
