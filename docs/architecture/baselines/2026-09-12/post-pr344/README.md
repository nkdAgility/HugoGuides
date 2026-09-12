# Post-prerequisite baseline — 12 September 2026

This supplements the original baseline; it does not overwrite the failed-build evidence. PR 344 is merged at `7ce0683dd1548af108e391a31e34fe43c6f10d90`. Platform work remains on `codex/open-guide-platform` / HugoGuides PR 35. E00 remains open until the outstanding verification below is complete.

## Build and deployment evidence

All twelve isolated builds pass with exit 0 and no ERROR lines: HugoGuides, KanbanGuides, the-safe-delusion and ScrumGuide-ExpansionPack, each in local, preview and production configurations. Exact source revisions and tool identities are in `baseline.json`. These are raw Hugo builds; deployment configuration packaging is a separate concern.

The merged Scrum prerequisite deployed to **shared Preview**, not production. Workflow run [34723426309](https://github.com/ScrumGuides/ScrumGuide-ExpansionPack/actions/runs/34723426309) selected Preview and version `2.0.10-preview.5`. Its logs identify [the deployed site](https://agreeable-island-0c966e810-preview.centralus.6.azurestaticapps.net/). All 167 HTML pages, 31 PDFs and 3 CSS/JavaScript assets checked match that run's Site artifact byte for byte. The 35 HTML redirect files were excluded from byte comparison. This verifies the selected published files, not the final merged Azure hosting configuration.

An initial comparison of that preview artifact against scrumexpansion.org was invalid because it used the wrong ring. Its mismatches are not evidence of a production regression. No production promotion was performed by this task.

The earlier PR-specific preview check covered 175 HTML pages, 31 PDFs and 3 assets, all matching its artifact. Browser checks covered guide navigation, Persian current-edition English fallback, version selection, and the historical Persian RTL guide with its Persian download. Historical Persian horizontal overflow was also observed on production at the same 1280-pixel viewport (1327-pixel document width).

## Preservation and findings

- All supplied PDF hashes match the initial baseline in all three consumers: Kanban 35, safe-delusion 1, Scrum 31.
- Kanban production has no `min/` HTML routes and no `*.min.pdf` downloads.
- The shared Scrum preview contains two missing internal navigation targets from `it/emergent-strategy-and-depoyment/2026.1/`: the default-language history and translations pages. Record this as an existing-source baseline finding for E05; do not silently accept it as desired behavior or fix multilingual resolution during relocation.
- Planguage has missing `#36` and `#60` anchors on the explicit and latest edition routes. Their source links predate PR 344; its guide-body diff is empty. Disposition: consumer editorial finding, outside the prerequisite fix.
- Persian horizontal overflow is an existing presentation finding. Disposition: preserve the observed baseline during relocation; assess any correction separately from the module move.
- HugoGuides PRs 33 and 34 remain separate reported module defects. They have not been incorporated or approved by this work.
- The reference site actively mounts KanbanGuides `content` and `i18n`; its dependency is not unused. E02 must provide deliberate example inputs before removing that dependency. Preserve the module's multilingual implementation.

The implementation owner tracks these findings through E00/E05. Consumer editorial and presentation changes require a separately scoped disposition; they are not automatic migration edits.

## Governance and recovery inventory

`governance.json` preserves rule bodies and successful main-run references. `repository-integrations.json` captures repository identity, traditional branch-protection availability, webhook metadata without configuration URLs, Pages availability, environments, Actions permissions, secret names, tags and releases. Failed lookups are recorded as unavailable/absent, not as proof of a setting. Tags/releases were requested with a 100-item page limit; completeness must be checked before administrative cutover.

Observed required checks:

| Repository | Checks |
|---|---|
| HugoGuides | Build Site |
| KanbanGuides | Build Site, Publish Site, license/cla |
| ScrumGuide-ExpansionPack | Build Site, Publish Site, license/cla |
| the-safe-delusion | No rulesets returned; traditional branch protection lookup unavailable/absent |

The final Prepare/Build/Validate/Deploy/Verify check identities remain the plan. These observations do not require retaining the old names. No rules, credentials or deployment settings were changed.

The target repository lookup for `nkdAgility/OpenGuidePlatform` returned 404. It is not an occupied repository visible to this identity; availability still requires rechecking at rename. The four known workflow directories contain no reusable workflow caller referencing HugoGuides. This search does not establish the absence of external consumers.

`publication-inventory.json` records HTML routes, PDF hashes and wrapper override paths for each repository and ring. Full source archives, artifact hashes and logs are retained under `.processing/baseline-post-pr344`. The original source inventories remain valid for the other three repositories; the merged Scrum source inventory is included here.

## Remaining E00 work

- Complete semantic guide/edition/language state and heading-anchor inventories, with explicit intentional exclusions and fallbacks.
- Complete representative browser baselines for Kanban, safe-delusion and the reference wrapper; do not substitute a successful build for visual review.
- Resolve the effective deployment/recovery identity for each site from ring-specific successful runs and artifacts; a successful main build alone is insufficient.
- Finish governance ownership and external enforcement feasibility assessment, including permissions that could not be observed.

No source relocation or module refactoring has started. E01 contracts and E02 relocation follow completion of these baseline checks.
