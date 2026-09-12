---
name: guide.genpdfs
description: "Plan and generate a new guide PDF using declared filenames, explicit language metadata and installed tools."
---

Read [Core usage](../USAGE.md). Select guide, edition, language and the exact download path declared in policy. Only generated downloads are eligible; supplied/protected resources are preserved.

Use `Get-GuidePdfPlan` to inspect source, destination, arguments, fonts and fingerprints. Use `Get-GuidePdfToolchain` for diagnostics, then `New-GuidePdf` with the same selections. HeaderPaths, LuaFilterPaths and FontOverrides are explicit choices; preserve the consumer's approved PDF recipe. Do not silently substitute fonts or install packages. The command passes the filename/default language to Pandoc metadata and never needs lang in Hugo front matter.

The initial extracted generator creates new outputs only and refuses existing PDFs. Do not bypass this by deleting a published file. Report a regeneration request as needing the reviewed replacement/fingerprint path still to be implemented.

After generation, inspect the actual PDF and render representative pages, including RTL/CJK cases when applicable. A successful native command or PDF header is not visual approval. Record source/config/toolchain fingerprints and any font/tool warnings; keep published filenames unchanged.
