# Initial execution baseline — 12 September 2026

Status: source and raw build baseline captured; E00 is not complete. No module relocation, module refactoring, repository rename, consumer adoption or deployment has occurred.

Implementation branch: codex/open-guide-platform in HugoGuides.

## Evidence

The collector archives each fetched origin/main commit into a new isolated directory. It records SHA-256 hashes before building, and runs local, preview and production configurations with explicit matching environments. Production here means a local build using production configuration, not a deployment.

| Repository | Commit | Module dependency | Local | Preview | Production |
|---|---|---|---|---|---|
| HugoGuides reference | 980366a80eb7b9b6a0098229aea43e9401536232 | Reference site imports KanbanGuides; local sibling replacements retained | Pass | Pass | Pass |
| KanbanGuides | cb991c4df952309cea51cb677b5134350c359ba7 | HugoGuides module v0.8.4 | Pass | Pass | Pass |
| the-safe-delusion | 1a597cf1eeb5863acec3cdf3f3b8b0c5f1c729bb | HugoGuides module v0.6.8 | Pass | Pass | Pass |
| ScrumGuide-ExpansionPack | 280f83da1ac0b5fb3adc139cc345c083a94c4928 | HugoGuides module v0.8.3 | Fail | Fail | Fail |

Toolchain: Hugo Extended 0.164.0, Go 1.26.5, PowerShell 7.6.5, Windows amd64. The machine-readable baseline records the exact Hugo build identity and warning counts. This is an explicit test toolchain, not yet the chosen release toolchain.

The existing safe-delusion checkout remains on more-updates with an untracked AGENTS.md. Its current remote main, not that checkout, was archived. The other consumer checkouts were also left unchanged.

## Existing blocker requiring disposition

ScrumGuide-ExpansionPack contains a top-level front matter field at site/content/adaptive-enterprise/2026.1/index.md:14:

    lang: en

All three builds fail with:

    ERROR deprecated: lang in front matter was deprecated in Hugo v0.144.0 and subsequently removed.
    ERROR error building site: logged 1 error(s)

The emitted files from those failed builds are incomplete output, not an accepted baseline. The content has not been edited. Proposed minimal repair for a separate consumer change, if authorised: remove the obsolete front matter field while retaining the existing index.md source-language convention, then rebuild all three configurations and compare rendering. This proposal is not an assertion that there are no further issues after that fix.

Decision needed from Martin: disposition of this pre-existing consumer failure before approving the all-sites baseline. Do not bypass the failure or quietly change audited guide content during platform extraction.

## Existing module fixes under review

Two existing open HugoGuides PRs affect the behaviour we will compare:

- [PR 33: Pass author context as a dict to guide-author.html](https://github.com/nkdAgility/HugoGuides/pull/33), head 5ccbd98715a29b4ad90fe160286585c1b88f432b.
- [PR 34: Match the language when falling back to a translation page's PDF resource](https://github.com/nkdAgility/HugoGuides/pull/34), head 15c86ac3df396a2f77a6c23051f987ab90975859.

Their descriptions report missing contributor details and incorrect translated PDF selection. Those reports have been inspected, but the fixes have not been independently accepted, merged or incorporated here. Track them as known defects; do not make regression tests demand faulty output. Rebaseline explicitly if either fix becomes part of the migration source.

## Governance snapshot

All four repositories report ADMIN access for the current GitHub identity. Their default branch is main.

| Repository | GitHub node ID | Observed ruleset names |
|---|---|---|
| nkdAgility/HugoGuides | R_kgDOO4lKLg | Default-Bypass-Allowed; Default-NoBypass |
| KanbanGuides/KanbanGuides | R_kgDOPD_D7A | Default-Bypass-AdminAllowed; Default-NoBypass |
| nkdAgility/the-safe-delusion | R_kgDONPQHwA | None returned by rulesets listing |
| ScrumGuides/ScrumGuide-ExpansionPack | R_kgDOO4J4dA | Default-Bypass-AdminAllowed; Default-Bypass-MaintainAllowed; Default-NoBypass; Restrict-Tags |

Ruleset names alone are not proof of the effective checks or traditional branch protection. Detailed rule bodies, external enforcement capability, integrations and recovery artifacts still need assessment. No GitHub configuration was changed.

## Reproduce

Fetch remotes first, then run from HugoGuides with a new output directory:

    pwsh -File .build/Measure-ConsumerBaseline.ps1 -RepositoryRoot C:/Users/MartinHinshelwoodNKD/source/repos -OutputPath C:/Users/MartinHinshelwoodNKD/source/repos/HugoGuides/.processing/baseline-rerun

The collector fails if any build fails, after writing the summary and individual logs. Reusing an existing output directory is refused to avoid mixing baselines. No global Hugo or Go caches are deleted.

Committed evidence includes source hashes and the build summary. Full archives, generated sites, per-artifact hashes and build logs remain under the ignored .processing/platform-baseline-20260912 directory. Archive these as CI artifacts when this collector runs in CI.

## Scope and outstanding verification

- Raw Hugo builds do not reproduce workflow token substitution, GitVersion, hosting configuration packaging or deployed artifacts.
- Content source hashes preserve evidence; they do not establish that the resulting rendering is correct.
- Full visual comparisons, semantic route/anchor/download assertions, effective-language/cascade inventories and actual browser interactions have not yet been accepted.
- No Hugo module files or consumer source files were changed. Warnings remain visible and have not been suppressed.
- The platform reference site's dependency on the Kanban site still exists. Its local sibling replacements are reproduced rather than redesigned in this baseline step.

Next: resolve the Scrum baseline disposition, account for the two module fix PRs, finish baseline verification, then proceed with mechanical structure and shared tooling. Repository rename and production promotion remain explicit later approval points.
