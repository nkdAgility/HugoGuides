# Cross-consumer relocation evidence — 13 September 2026

Candidate module: 84247fd8d0db3837ec067c47261eef99efacfbc1. Original module: 980366a80eb7b9b6a0098229aea43e9401536232. All 73 moved module files still match the E02 manifest. Consumer revisions are the previously captured post-PR344 baseline, not an assertion that every remote main remains unchanged.

The harness built archived copies of KanbanGuides, the-safe-delusion and ScrumGuide-ExpansionPack against three dependency variants: each consumer's pinned module, the original module before relocation, and the relocated module. Each variant built local, preview and production. All 27 builds passed. A further nine builds repeated the original control with the same source path, clock and cache; all passed. No consumer checkout or deployed site changed.

Hugo 0.164.0 Extended, Go 1.26.5 and a fixed Hugo clock of 2026-09-13T00:00:00Z were used. Remote language resources use a shared Hugo cache; network-dependent behavior has not been made hermetic. These are raw Hugo artifacts, not the final hosting package.

## Results

| Site | Module pin | Artifact files: local / preview / production | Relocation observations |
|---|---|---|---|
| KanbanGuides | v0.8.4 | 335 / 302 / 225 | Same route/file inventory and PDFs; debug checkout paths differ; duplicate shared aliases select different destinations between builds. |
| the-safe-delusion | v0.6.8 | 50 / 50 / 50 for current module; 49 for pinned | Original and relocated production artifacts are byte-identical. Local/preview differences are only printed checkout paths. Updating from the older pin also changes assets/output and adds footnote-tooltips.js. |
| ScrumGuide-ExpansionPack | v0.8.3 | 499 / 483 / 329 | Same route/file inventory and PDFs; checkout paths, sitemap ordering and some share-script/redirect output differ. The unchanged control also varies. |

No PDF differs in any comparison. All original-versus-relocated artifact path inventories are identical. No HTML route is added or removed between a pinned and current-module build; the one added resource is Safe Delusion's JavaScript file.

The byte comparisons are retained without normalization in comparison.json. difference-classification-v2.json separately identifies changes explained solely by the absolute consumer/module checkout paths printed by existing debug panels. It does not approve or suppress other differences. Pinned-module comparisons also include LF/CRLF variation in template-generated HTML; raw difference counts must not be described as counts of functional changes.

## Existing variability that blocks an unconditional equivalence claim

- Kanban translations pages for both guides declare the same /download/, /downloads/ and /translationsdirectory/ aliases in several languages. Rebuilding the unchanged control changes which guide wins those routes. The repeated original changed 13 local, 10 preview and 8 production files.
- Scrum control rebuilds changed 14 local, 14 preview and 2 production files. Sample sitemap differences reorder alternate-language links. Sample HTML differences move the copy-link script/toast between latest/explicit edition output. The existing share-dropdown partial uses mutable Page.Scratch with a clock-based key; its copy URL can include the pre-existing %!s(<nil>) value. These observations identify existing behavior; they are not permission to refactor the multilingual module.
- Safe Delusion's original control was byte-identical on repeat in all three rings.

These findings remain open. The user clarified that the shared aliases exist only for legacy compatibility: preserve their current implementation during adoption, do not extend them or require them for new languages, and do not require a new owner-selection decision now. Guardrail integration must distinguish the frozen existing legacy declarations from new collisions; share/copy behavior remains recorded for later module work. Do not regenerate an accepted baseline or label all remaining differences harmless. E05 acceptance and visual/functional verification are not complete. Existing consumer pins must not be automatically upgraded on the strength of this relocation check.

## Reproduction and retained output

Run .build/Measure-ModuleRelocation.ps1 with the post-prerequisite BaselinePath and a fresh direct child of .processing as OutputPath. Then run .build/Explain-ModuleRelocationDifferences.ps1 and .build/Measure-ModuleRepeatability.ps1 against that output. Helpers archive exact Git commits and invoke tools with bounded timeouts; consumer working trees are not switched or edited.

Full archived sources, inventories and logs remain in .processing/e05-relocation-20260913. The first repeatability attempt failed before rendering because PowerShell deserialized the clock into DateTime and formatted it for the current culture. The harness now converts it back to UTC RFC3339; repeatability-2.json is the successful attempt. Failed logs are preserved locally.
## Additional static navigation characterisation

[Navigation evidence](navigation-validation.json) applies the current platform checker to all 27 retained artifacts. This is a new analysis of the recorded builds, not 27 new builds. All 6,966 retained file hashes were reverified against their original inventories. Exact findings (code, source page and target), including repeated occurrences, match original versus relocated for all nine site/target pairs.

| Site | Pinned findings: local / preview / production | Original and relocated findings: local / preview / production |
|---|---|---|
| KanbanGuides | 17 / 356 / 260 | 17 / 356 / 260 |
| the-safe-delusion | 8 / 25 / 26 | 8 / 28 / 29 |
| ScrumGuide-ExpansionPack | 34 / 38 / 4 | 34 / 38 / 4 |

Counts are link occurrences, not distinct broken destinations. The files record exact findings for review. Several classes need different treatment before adoption:

- Missing `/images/user-default.png` accounts for most preview/production findings. These are raw Hugo artifacts; distinguish hosting/configuration processing from actual missing assets before prescribing a consumer change.
- Kanban references a historical guide URL and some Spanish `latest` URLs absent from the raw artifact. Check existing hosting redirects and case-sensitive publication routes before changing anything.
- Safe Delusion has five `#content` findings in each artifact: its existing script assigns that ID to `main` at runtime. Static absence is not evidence that browser navigation fails. Two appendix-anchor occurrences also need an exact heading/runtime check.
- Scrum local/preview references missing image resources and numeric anchors. Its four production findings are the default avatar resource. Preserve exclusion differences between targets.
- Doubled-slash translation URLs also occur in existing output. Their deployed/hosting behavior needs verification; no redirect or module rewrite is authorized by this analysis.

This evidence supports mechanical-relocation equivalence for the checked navigation, while keeping known consumer findings open. It does not make those findings acceptable, prove all JSON/catalogue semantics, or approve visuals. Reproduce by running `.build/Test-GuideSiteNavigation.ps1` against each `artifacts/<repository>/<variant>/<target>` directory with the canonical origin recorded in the evidence file, then compare the exact `Findings` records. The checker commit and SHA256 are recorded.
## Selected runtime-anchor verification

[Browser evidence](runtime-anchors.json) records fourteen page observations across the original and relocated raw local artifacts using Playwright 1.63.0 / Chromium 153.0.8010.12. Requests to the consumer origin were fulfilled from retained artifact files; all external origins and non-read requests were blocked. No deployed site was contacted or changed. This intentionally bounded replay is not a complete network-dependent or visual acceptance test.

Safe Delusion's five `#content` destinations existed as `main#content` after its own JavaScript ran. Keyboard activation of each skip link reached the hash and a visible target, in both module variants. The static check must not become a blanket exemption: normal build integration still needs equivalent browser evidence for declared runtime anchors in the current artifact.

The appendix destination `appendix---safe-alternatives-to-safe` remained absent in both variants. The actual heading ID is `appendix-3---safe-alternatives-to-safe`. Scrum's Planguage `#36` and `#60` destinations also remained absent in both latest and explicit edition output. These are pre-existing findings to resolve or explicitly disposition in the relevant adoption work; this analysis does not authorize protected guide edits or premature module refactoring.

The replay helper uses the [Playwright library](https://playwright.dev/docs/library) with explicit request interception and browser cleanup. To repeat it after reproducing the retained artifacts:

```powershell
npm install --prefix .processing/browser-tools --no-audit --no-fund --ignore-scripts --package-lock=false --save=false '@playwright/test@^1'
$env:PLAYWRIGHT_BROWSERS_PATH = "$PWD/.processing/browser-tools/browsers"
node .processing/browser-tools/node_modules/playwright/cli.js install chromium
node .build/Measure-RetainedGuideAnchors.cjs .processing/e05-relocation-20260913/artifacts docs/architecture/baselines/2026-09-13-relocation/navigation-validation.json .processing/browser-tools .processing/e05-runtime-replay
```

Use a fresh output directory and record the tool/browser versions of each new run. The helper refuses an existing output directory and records its source SHA256. These optional characterization tools are separate from everyday guide-site prerequisites.

## Rendered semantics and targeted visual comparison

[Semantic comparisons](semantic-comparison.json) cover every HTML page in the 27 retained builds and nine repeat controls, after rechecking all 9,289 file hashes. The checker compares language/direction, headings, main text, IDs, ordered links and redirects separately. Whitespace normalization and script/style exclusion are explicit; full text still captures debug panels. No baseline or finding was suppressed.

Original-versus-relocated production semantic differences are confined to Kanban's recorded legacy alias outputs. Scrum and Safe Delusion production semantics match. Scrum local/preview main-text differences are the existing copy-link toast containing `%!s(<nil>)`; repeat-control variability remains recorded. Full-text changes in local/preview also include printed checkout paths.

The older Safe Delusion v0.6.8 pin differs from the original/current module: the guide title changes from H2 to H1, the contributor label loses its text, homepage contributor text changes, and some catalogue labels/links differ. The [pinned guide viewport](safe-delusion-visuals/pinned-guide.png) and [newer-module viewport](safe-delusion-visuals/original-guide.png) confirm title-size and layout changes. Both use the same captured Bootstrap assets. External avatars/font icons are blocked, so these images do not certify complete visual equivalence; their limits and asset hashes are recorded alongside them.

These are pre-existing module-upgrade differences, not relocation-induced guide content edits. The maintainer explicitly accepted these existing updates on 2026-09-13, so they no longer block adoption of the newer module. Coordinated platform/Hugo versioning is retained. E05 remains open for the remaining representative visual review and state coverage across all guides. No consumer source or module template was changed to hide the findings.


## Completed rendering-state comparison

[State evidence](rendering-state-comparison.json) adds 79 preview and six local routes, compared at top, middle and bottom. All 255 original/relocated pairs match exactly with Bootstrap loaded. All 18 guides are represented, including the two guides suppressed outside local builds. The production replay adds 29 matching pairs. External avatars/icons remain blocked; no claim is made about their service availability. The execution-plan closure records accepted updates, known defects and remaining adoption verification separately.
