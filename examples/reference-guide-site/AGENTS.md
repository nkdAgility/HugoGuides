# GuideSiteSample instructions

This is the platform's independent test wrapper, with multiple guides and editions.
Use the repository root build.ps1; do not treat a direct Hugo invocation as the full validation.

From the repository root:
```powershell
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target preview
./build.ps1 -Product GuideSite -PolicyPath examples/reference-guide-site/guide-site.policy.json -Target production
```

Preview must exercise English, Japanese and Minionese navigation. Production must exclude Minionese.
Check homepage, every guide/edition, translations and history pages and local links. Missing translations must be declared honestly; never silently present English as a completed Japanese translation.
Verify the actual PR hostname returned by Azure. Successful upload or HTTP 200 alone does not establish correct rendering.
The sample can change without changing deployed guide instances or refactoring shared multilingual templates.
