# Baseline disposition and E01 handoff — 13 September 2026

E00 capture is complete as the starting evidence for contracts and mechanical migration. This is not an assertion that every existing page is correct, that production recovery has been rehearsed, or that later equivalence testing is complete. Known limitations have explicit dispositions below. E01 contract implementation is ready for PR review; E02 source moves have not started.

## Browser and rendered-output observations

Three archived production-configured wrappers were served locally on 127.0.0.1, without changing their source or deployed sites. At a 1280 by 720 viewport, browser screenshots showed Kanban's two-guide card layout, safe-delusion's bespoke editorial navigation and reference guide catalogue. Kanban and safe-delusion had no broken images. The reference logo `/images/guides-logo-dark.png` was missing. All three had document widths of 1265 pixels, within the viewport. The reference catalogue included its two own guides and both imported Kanban guides.

These observations complement the earlier Scrum preview/Persian browser checks. They are initial representative observations; E05 will establish automated comparison coverage for every guide and rendering state before any relocation/adoption candidate is accepted. Browser screenshots were inspected in the task; the committed evidence here contains source identities and semantic inventories, not a portable screenshot test suite.

`rendered-semantics.json` records initial HTML language/direction attributes, heading fingerprints, IDs and redirects across all twelve artifacts. It reports static link candidates separately from accepted behavior. Counts include redirect pages:

| Repository | Local HTML / findings | Preview HTML / findings | Production HTML / findings |
|---|---:|---:|---:|
| HugoGuides | 63 / 16 | 84 / 9 | 84 / 9 |
| KanbanGuides | 138 / 1 | 123 / 14 | 89 / 18 |
| the-safe-delusion | 15 / 7 | 15 / 8 | 15 / 8 |
| ScrumGuide-ExpansionPack | 210 / 4 | 202 / 6 | 132 / 0 |

A finding is not automatically a deployed failure. In particular, safe-delusion's `#content` anchor is supplied by its skip-link JavaScript and was confirmed present in the browser DOM. Hosting redirects can also affect target resolution. E05 must compare runtime behavior and hosting rules before turning remaining candidates into blockers. External URLs were not checked. The raw outputs contain unresolved workflow version tokens, so they are not deployment-ready artifacts.

Disposition owners: platform implementation owns characterization and distinguishing regressions; consumer maintainers own editorial or wrapper corrections; module maintainers own the separate existing PR 33/34 fixes. None of these findings authorizes a content rewrite or an internal module refactor during relocation.

## Recovery and governance disposition

GitHub's deployments API returned no deployment records for all four repositories. These workflows report Azure deployment URLs through Actions logs instead.

- Kanban main run 34716492078 used Preview, commit cb991c4df952309cea51cb677b5134350c359ba7, and deployed to `https://red-pond-0d8225910-preview.centralus.2.azurestaticapps.net`. Site artifact 10304749250 was retained at inspection.
- Scrum main run 34723426309 used Preview, commit 7ce0683dd1548af108e391a31e34fe43c6f10d90; its deployed files were verified against the downloaded artifact.
- HugoGuides run 25063075178 logs returned HTTP 410 and no retained artifact was listed.
- safe-delusion run 31189824060 logs returned HTTP 410; Site artifact 8998322308 is expired.

Recovery method for an expired artifact: restore the recorded Git source and dependency pins into an isolated checkout, use the recorded successful toolchain, reproduce the original ring's version/token and hosting-configuration steps, validate that output against the observed live site and protected hashes, then retain the validated package and its identity before any approved deployment. The raw baseline proves source builds, not byte-equivalent deployment recovery. Platform implementation must exercise this method and establish exact deployed production identities in E07 before E08 cutover; do not rely on rerunning an old workflow with `latest` tools. Consumer owners approve any actual recovery deployment.

Current rules and permissions are captured. Existing repository administrators own the future external enforcement configuration; exact team/App identities and available required-gate mechanisms must be verified in E06 before installation. Unavailable traditional protection/Pages endpoints are not silently treated as successful checks. This does not block defining contracts that explicitly distrust candidate-controlled policy authority.

## E01 implementation

Three versioned schemas cover site policy, assessment results and release locks. Contract fixtures represent the actual one-, two- and fifteen-guide shapes while remaining explicitly incomplete, non-installable examples. Four architecture decisions record coordinated releases, unchanged Hugo inputs during migration, workflow identity and external policy authority.

The local PowerShell harness passes 18 positive and negative checks. CI invokes the same harness through a thin workflow with read-only permissions and an immutable checkout action. Schema tests do not claim that E03 semantic validation, E04 stage orchestration, E06 trusted enforcement or E07 package verification already exists.

The module and all consumer source files remain untouched by E00/E01 platform work. Continue with a separately reviewable E02 move manifest only after reviewing this contract candidate and accounting for the reference site's active imported content.
