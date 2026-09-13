# Publishing Core (candidate)

This PowerShell 7.4 module contains publishing operations organised by capability. It accepts an explicit workspace and reviewed site policy; it has no GitHub or agent dependency. Guide and edition collections are not limited to fixture counts.

```powershell
Import-Module ./system/OpenGuidePlatform.PowerShell.Core/OpenGuidePlatform.PowerShell.Core.psd1
$policy = Import-GuidePolicy -Path ./path/to/reviewed-site-policy.json
Get-GuideInventory -WorkspaceRoot $PWD.Path -Policy $policy
```

Policy loading and document operations use powershell-yaml 0.4.12. Only PDF generation requires Pandoc and XeLaTeX; explicit font choices require font diagnostics. No command installs fonts automatically. Tests require Pester 5.7.1; run `./.build/Test-PlatformCore.ps1` from the platform root.

Capabilities include inventory and translation readiness, publication exclusions, write-policy decisions, empty translation scaffolding, draft edition snapshots, new contributor records, Gravatar hashing, and new PDF generation. Mutation commands support WhatIf. Supplied and protected downloads cannot be regenerated. Existing destinations are refused or preserved, never force-overwritten.

PDF language comes from the filename suffix or declared source language and is passed explicitly to Pandoc metadata. Source front matter does not need a lang field. Generation checks native failures and PDF format before publishing a new file; returned evidence includes input, policy, executable and output hashes. Visual review remains necessary.

This module enforces the supplied policy, not the authenticity of that policy. The independent trusted gate is E06. These are development candidates, not an installable release; pinned distribution is E07.

## Remaining E03 work

- Effective Hugo catalogue fallback and wrapper content reconciliation; local YAML checks are available through Get-GuideWrapperStatus, with runtime route/integration observations supplied separately.
- Build adapter wiring for PDF receipts and approved environment fingerprints; automatic reuse is off without complete evidence.
- Abrupt process termination during a snapshot can leave a staging directory/lock for manual inspection; handled copy failures clean up staging and never publish a partial edition.
- Complete regression coverage for those operations before declaring E03 finished.

Shared skills describe these boundaries explicitly. Root Prepare/Build/report orchestration belongs to E04. Nothing here changes Hugo rendering or adopts the platform in a consumer.
Fallback observation follows declared chains to populated web content and treats cycles, undeclared targets and non-web targets as unavailable. Edition snapshots publish by a same-parent directory rename after all files are copied. An existing destination is never replaced.

Contributor updates accept exact candidate YAML, one existing contributor name and the reviewed source SHA-256. They preserve the existing .yml/.yaml path and reject semantic changes to other records. Candidate comments and formatting must be reviewed because the command writes the supplied text exactly. A cooperative lock, staged replacement and second hash check catch observed conflicts; they are not an OS-level compare-and-swap against other editors. Existing site-specific roles are retained. Adding, removing and renaming records through this update operation are unsupported.

Generated PDFs can now be replaced using ExpectedOutputSha256. They remain untouched on rendering/input failures; supplied/protected downloads remain ineligible. A successful receipt can carry CacheKey when EnvironmentSha256 is supplied. Test-GuidePdfCache rechecks input/output hashes and recipe/tool/environment evidence; callers must provide a digest covering fonts, TeX packages and indirect resources. No timestamp-based reuse occurs. Local wrapper catalogue checks support YAML mappings/sequences and numeric/script language tags; they do not claim effective Hugo fallback or plural completeness. Required routes/integration points remain unknown until the build adapter provides observations.
