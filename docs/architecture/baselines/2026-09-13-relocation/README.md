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