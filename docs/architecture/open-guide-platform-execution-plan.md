# OpenGuidePlatform execution plan

Status: implementation is on `codex/open-guide-platform`, PR #35. E00 and the E02 mechanical relocation are complete. E03 is complete with the reconciled wrapper operations and common readiness path verified locally and in CI. E01 and E04–E08 remain open against their full acceptance criteria. The repository has already been renamed to `nkdAgility/OpenGuidePlatform`; preview release `v0.5.3-PullRequest0035.139` and the reference site's five-stage preview workflow passed at commit `8d1822027afde92a951f09bf070dab0819cb5235`. E09–E14 remain outstanding. No consumer adoption or production deployment is implied by the sample results. The implementation follow-up register below records remaining findings without changing the original work-package IDs or ordering.

Companion: [architecture and adoption proposal](open-guide-platform-proposal.md).

## Outcome

Rename the existing public `nkdAgility/HugoGuides` repository to `nkdAgility/OpenGuidePlatform`, preserve its Git history and releases, move its reusable code into named `system/` components, and adopt the resulting platform in KanbanGuides, the-safe-delusion and ScrumGuide-ExpansionPack.

Each consumer retains its bespoke wrapper and guide content. The platform supplies guide rendering, publishing operations, validation, distributed skills, agent controls and shared GitHub workflows. The same supported build operations run locally and in CI.

This is an execution plan, not authorisation inferred to rename or deploy immediately. Repository names and locations below are the proposed targets; confirm availability and current ownership during preflight. No new GitHub repository is needed for the main platform.

## 1. Scope and non-negotiable constraints

- Rename the existing repository rather than copy its current files into a new repository with unrelated history.
- Preserve all existing releases and tags. Never retag historical module versions or replace their assets.
- Move shared implementation and example content into OpenGuidePlatform. Keep published guide content and bespoke wrappers in their consumer repositories.
- Implement changes on feature branches with reviewable PRs and immutable preview candidates. Preview verification is not production deployment authorisation; repository rename remains an explicit administrative cutover.
- During migration and adoption, keep Hugo module internals unchanged apart from the minimum path/reference changes needed for mechanical relocation and identity updates. Preserve functionality and visual output.
- The existing multilingual guide and edition structure is deliberate, even where it differs from conventional Hugo usage. Do not normalise language resolution, fallbacks, cascades or content organisation during adoption.
- Keep the proposed refactoring of Hugo module contents in E14, after the rest of the platform has been built and verified against the guide sites. Production adoption and operational handover are not prerequisites.
- Make content/layout moves separately reviewable from behavioral changes.
- Protect the audited safe-delusion guide, its PDF and its rendering contract. A platform adoption is not permission to rewrite that guide.
- Preserve public routes, PDF URLs, heading anchors, contributor records and intentional publication exclusions unless a specific approved migration changes them.
- Keep KanbanGuides Minionese permanently ineligible for production. Do not infer an equivalent permanent Klingon rule without a Scrum policy decision.
- Never interpret missing review, skipped required checks, failed validators or unknown deployment state as success.
- Never give untrusted PR code production credentials or authority to replace its own mandatory check.
- New stage names are Prepare, Build, Validate, Deploy and Verify. Required checks will be updated to match; compatibility with old check names is not a design constraint.

## 2. Work map and ordering

| ID | Work package | Depends on | Reviewable output |
|---|---|---|---|
| E00 | Refresh and baseline all repositories | None | Inventory, hashes, routes, configuration and governance snapshot |
| E01 | Define platform contracts and ownership | E00 | Contracts, architecture decisions and consumer policy drafts |
| E02 | Move existing platform source and examples | E01 | Mechanical relocation PR with move manifest |
| E03 | Extract publishing operations and skills | E02 | Core module, corrected skills and regression tests |
| E04 | Implement shared build and reports | E03 | Build module, stage commands, reports and artifact validation |
| E05 | Characterise existing Hugo behaviour without refactoring | E00, E02 | Cross-consumer regression coverage and output baselines |
| E06 | Implement agent governance and trusted gates | E03, E04 | Agent integrations and independently enforced policy |
| E07 | Implement packaging, adoption and shared workflows | E04, E05, E06 | Release assets, installer/updater and thin workflow templates |
| E08 | Rename repository and publish first preview | E07 | OpenGuidePlatform identity and immutable preview release |
| E09 | Pilot KanbanGuides | E08 | Adoption PR, preview verification and hardened rules |
| E10 | Adopt the-safe-delusion | E09 | Preserved audited guide and verified bespoke wrapper |
| E11 | Adopt ScrumGuide-ExpansionPack | E09 | Core/extension and multilingual adoption |
| E12 | Publish stable and promote consumers | E10, E11 | Stable release and separately verified site releases |
| E13 | Complete adoption transition and operational handover | E12 | Retired build duplication, update automation and operational documentation |
| E14 | Refactor Hugo module contents last | E05, E09, E10, E11 | Existing proposed refactoring, checked against working preview builds |

E05 adds tests and baseline evidence only and can run alongside E03/E04 after the mechanical move. E14 follows successful build and preview verification of the other platform work across the three sites. It does not wait for stable releases, production deployment or handover; its ID is retained for traceability. E10 and E11 can proceed independently after the Kanban pilot. Do not rename while the platform pipeline is still unable to build, package and validate the new paths.

Each work package should become an issue with this document's ID, and one or more bounded PRs. Mark a package complete only after its acceptance criteria are evidenced. This plan does not create those issues or PRs yet.

## 3. E00 — Refresh and establish the baseline

1. Inspect branches, remotes and working trees in HugoGuides, KanbanGuides, the-safe-delusion and ScrumGuide-ExpansionPack. Preserve uncommitted work; in particular, the previous assessment found an untracked safe-delusion `AGENTS.md`.
2. Fetch current remotes and establish clean implementation branches or worktrees from current default branches. Do not overwrite the assessment documents or other local work.
3. Re-read current repository instructions, contribution policies and relevant skills. Record changes since the proposal's local snapshot.
4. Record repository IDs, default branches, tags/releases, open PRs, rulesets, CODEOWNERS, workflow state, permissions, webhooks, Pages settings if applicable, and deployment integrations. Record secret names and scope, never values.
5. Confirm the destination name is available under `nkdAgility`; identify other consumers of the old module and any reusable workflow callers. Search the known repositories and document that external consumer discovery may be incomplete.
6. Pin a test toolchain and build each consumer using its existing dependency. Separate pre-existing failures from migration regressions. Do not silently broaden the migration to fix unrelated editorial problems.
7. Capture route/redirect/download inventories, language and guide eligibility, heading anchors, wrapper overrides and representative screenshots. Hash protected content and all supplied PDFs.
8. Inspect current example-site dependencies. The assessed HugoGuides `site/go.mod` references KanbanGuides while configuration includes a local module replacement; establish what is actually imported/mounted before moving it.
9. Establish a known-good deployment artifact or documented recovery method for each currently deployed site.

**Acceptance:** a dated baseline names exact source commits and tool versions; each known failure has an owner/disposition; protected-content hashes and existing route expectations are available. Work does not proceed on assumptions that every local checkout matches remote main.

## 4. E01 — Lock the contracts and component boundaries

Adopt these named components:

```text
system/OpenGuidePlatform.Hugo.Guides/
system/OpenGuidePlatform.PowerShell.Core/
system/OpenGuidePlatform.PowerShell.Build/
system/OpenGuidePlatform.AgentSkills/
system/OpenGuidePlatform.AgentControls/
```

Define and test schemas for site policy, wrapper requirements, guide inventory, edition/translation/download state, findings and release locks. Record the future publication-manifest contract as E14 work; do not require Hugo to consume a new manifest during adoption. Each schema has a version and migration behavior.

Core owns publishing operations and policy decisions. Build orchestrates them. Hugo retains its existing rendering inputs and behaviour during adoption; the future presentation/publication contract belongs to E14. GitHub, filesystem, Pandoc and agent integrations are adapters. Domain functions must not depend on GitHub environment variables or invoke external tools.

Consumer-owned configuration describes:

- Bespoke wrapper routes, language strings, assets and guide integration points.
- One or more guides and their edition storage conventions.
- Translation modes: web, PDF-only, English fallback, scaffolded or excluded.
- Guide/edition/language publication eligibility by environment.
- Protected source and supplied/generated PDF handling.
- Contributor versus maintainer capabilities and required reviewers.

Use architecture decision records for the coordinated release model, publication-manifest contract, stable workflow identity and protected-policy execution source. Establish approved owner groups before enforcement rollout.

**Acceptance:** all three consumers can be represented without hard-coded Kanban guide names, Scrum core slugs or a universal wrapper file list. Contract fixtures include the single-guide, two-guide and many-guide cases.

## 5. E02 — Move source and example content

Create a move manifest, then use explicit path moves with Git history retained. Review a mechanical move before reorganising implementation internals.

| Existing source | Destination | Treatment |
|---|---|---|
| HugoGuides `module/` | `system/OpenGuidePlatform.Hugo.Guides/` | Move tracked module source; exclude generated locks/caches/output. Change module identity in an explicit follow-up commit. |
| HugoGuides `site/` | `examples/reference-guide-site/` | Move demo source, then remove accidental production-consumer coupling through a separately reviewed change. |
| HugoGuides demo hosting configuration | Reference-site configuration or explicit hosting adapter inputs | Inspect usage before relocating; preserve any deployed demo route/domain contract. |
| HugoGuides `serve.ps1` and useful `.powershell/` helpers | Platform development commands / Build adapters | Inventory first; preserve supported entry points during transition. |
| KanbanGuides `.agents/skills/*/SKILL.md` | `system/OpenGuidePlatform.AgentSkills/` | Initially copy with provenance; retire consumer originals only after adoption installs replacements. |
| Kanban PDF/history/contributor/avatar scripts | Core capability directories | Extract implementation, retain authorship/licence information and add parameterised operations. |
| Kanban `cover-page.tex` | Core `PdfPublishing/templates/` | Shared default; consumer overrides explicit. |
| Assessment and execution documents | Platform `docs/architecture/` | Transfer the accepted versions when the platform working branch exists; avoid maintaining divergent copies. |

**Content that stays put:** all three sites' guide Markdown, translations, PDFs, contributor data, editorial content, bespoke wrapper layouts and assets. Test fixtures may use minimal synthetic data or approved pinned snapshots; do not turn the platform into a second canonical store of their publications. Preserve attribution/licensing for any copied fixture material.

Update development paths, module mounts, build instructions and tests atomically with moves. Resolve PowerShell resource paths from installed module locations, not assumptions about a script being nested inside `.agents/skills/`.

The reference site must build from the relocated module without requiring a neighbouring KanbanGuides checkout. Remove its KanbanGuides dependency only after proving it is unused or replacing the required example inputs deliberately.

**Acceptance:** move manifest accounts for every tracked source file; source/resource hashes agree where no semantic change was intended; reference build succeeds; no consumer published content has changed.

## 6. E03 — Extract Core and the seven skills

Implement GuideInventory, TranslationReadiness, PublicationPolicy, EditionManagement, ContributorManagement, PdfPublishing and AgentGovernance with narrow public commands and structured results.

Migrate the seven existing skill names. Correct hard-coded guide/edition lists, Minionese tone references, contradictory front matter rules, the reconcile production-enable default and historical path assumptions. Skills use the same operations as humans and CI.

PDF operations distinguish supplied, generated and protected resources. Add explicit guide/edition/language selection, tool/font diagnostics, source/template/configuration/toolchain fingerprints and multilingual fixtures. Preserve published filenames. Missing TeX does not block unrelated build operations.

Meaningful tests must demonstrate that scaffolding preserves populated translations, production remains disabled by default, PDF-only editions are valid, source-language detection handles `index.md`, numeric language regions work, and edition creation refuses conflicting targets. Confirm protected guide/PDF operations are rejected under contributor policy.

**Acceptance:** supported publishing commands work without an agent; readiness reports agree between skills and Prepare; no skill owns a second implementation of publication policy.

### E00–E03 acceptance reconciliation — 13 September 2026

This audit supersedes vague or stale progress statements in the early extraction notes and the initial implementation follow-up register. It evaluates the original package criteria, not later adoption or production readiness. Validation ran against implementation commit `83ffd1b910ac289256e92280bfb51b485b31e979`; only this execution document was modified during reconciliation. The final full `./build.ps1 -Version 0.0.0-local` also passed, including package verification.

- [x] **E00 Baselines refreshed and recorded, with known findings and explicit later verification/recovery gates.** The dated baseline records exact commits/toolchains for four repositories and twelve successful builds. Source, publication/PDF, guide-structure, semantic, governance and integration inventories exist. Known findings, owners/dispositions and the recovery method/limitations are recorded in the handoff. Re-read the JSON and verified all twelve recorded builds have exit 0 and zero errors. These are historical baseline results, not twelve new builds. Full cross-site equivalence remains E05; recovery rehearsal/cutover remains E07/E08 and does not reopen baseline capture.
- [ ] **E01 Contracts and policy ownership agreed.** The three versioned schemas, four ADRs and single/two/many-guide fixtures exist. All 19 structural checks passed again, including the synthetic 128-guide collection. Core/Build/adaptor boundaries and consumer ownership are documented. Remaining: reconcile ADR 001/003 and the workflow-lock contract's mandatory commit-pinning requirement with the later explicit instruction to use action version tags with only necessary restrictions; record the final ownership decisions required by E01. Candidate schemas/ADRs are not evidence of owner agreement. Installing/testing external enforcement belongs to E06, not E01.
- [x] **E02 Shared source/example content moved with provenance.** The 113-entry move manifest and separately recorded independent-example change exist. Reconstructed relocation commit `1d116dd` from Git: every manifest destination with disposition `move` exists, and all 73 moved module files match the recorded pre-move SHA-256. The example no longer imports KanbanGuides. Recorded standalone archive/example builds and current shared sample evidence support the independent example acceptance. Later intentional edits are not represented as byte-identical to the relocation snapshot. Native module identity changes remain E08; full consumer visual equivalence remains E05.
- [ ] **E03 Core operations and seven skills extracted and tested.** The detailed checklist below identifies the remaining work. Completion does not depend on adopting real consumers, independent enforcement or publishing a stable release.

E03 completed implementation:

- [x] All seven capability groups have executable Core commands, callable without an agent, and the seven original dotted skill identities reference shared commands. Provenance and licence records exist.
- [x] Guide/edition selection is parameterised; readiness handles source `index.md`, numeric/script language tags, empty bodies, populated scaffolds, PDF-only states and declared fallback chains.
- [x] Scaffolding preserves populated files, requires explicit production disablement and does not propagate the existing shared legacy download aliases into new languages.
- [x] Edition creation preserves source content, stages draft snapshots, rejects protected/conflicting destinations, and tests handled copy failure and concurrent destination preservation.
- [x] Contributor creation/reviewed updates and Gravatar operations are implemented and tested without rewriting unrelated contributor records.
- [x] PDF generation distinguishes generated/supplied/protected resources, preserves published names, passes Persian language explicitly, diagnoses tools/fonts and records source/resource/configuration/toolchain evidence.
- [x] Reviewed generated-PDF replacement and cache-evidence validation are implemented, with tests for stale evidence, changed input/recipe and native/non-PDF failures preserving the previous output. They are no longer missing E03 implementation.
- [x] Effective Hugo catalogue/module fallback observation exists and is consumed by Prepare. Core can accept that evidence. The real probe passed for Persian, a numeric region, module catalogues, fallback, missing keys and unchanged module pin. Effective fallback implementation is no longer wholly outstanding.

E03 remaining acceptance:

- [ ] Complete policy-driven wrapper/i18n creation and reviewed reconciliation, preserving bespoke consumer structure. `New-GuideTranslationScaffold` currently creates a guide document only; distributed transcreate/transreconcile explicitly leave wrapper/configuration/i18n repairs to a separate reviewed diff. Full wrapper reconciliation was part of the extraction scope and has not been delivered by that guide-only operation.
- [ ] Make the distributed translation status/reconciliation workflow consume the same effective translation evidence as Prepare. Today Prepare calls `Get-GuideEffectiveTranslations` and passes the result to Core, while the skills direct callers to local wrapper catalogue checks and disclaim effective module fallback. A module-provided translation can therefore receive different readiness findings through the documented skill path.
- [ ] Add acceptance tests for that shared skill/Prepare evidence path and the remaining wrapper operations, including preservation of populated translations and intended fallback. Existing seven-skill checks validate metadata, references and exported commands; they do not prove end-to-end readiness parity.
- [ ] Correct stale extraction/Core/skill documentation when those supported paths are completed; do not leave documentation saying already implemented PDF replacement or effective fallback is absent.

Explicit scope corrections: Build wiring that collects/persists approved PDF environment receipts belongs to E04; it is not a reason to call the implemented Core PDF/cache operations incomplete. Independent agent enforcement is E06; complete native distribution is E07/E08; real site adoption is E09–E11. Automatic recovery from abrupt process termination is not an added E03 acceptance requirement: the original plan requires refusal/preservation of conflicts, and the current crash residue limitation remains documented.

Fresh validation: `./build.ps1 -Stage Build -Version 0.0.0-local` exited 0, with 129 Pester tests passed (zero failed/skipped), 19 contract checks, seven distributed-skill checks and the real Hugo translation probe passed. PDF native failure/replacement tests use controlled fixtures; the earlier real Persian render is recorded evidence, not a new visual inspection in this audit. No production deployment or consumer modification occurred.

## 7. E04 — Implement Build, validation and reporting

Create the consumer stage interface described in the proposal. The bare command runs Prepare, Build and Validate with no deployment side effects. `-Versions` runs before importing dependencies that may be missing.

Build generates necessary configuration overlays and assessment reports in an output directory without changing Hugo rendering inputs or requiring a publication manifest, invokes the pinned Hugo toolchain, and packages the final hosting configuration in the actual artifact. Enforce native command exits, unresolved tokens, size limits and clean ring-specific output. Reject unsafe output/extraction paths.

Prepare collects all independent findings, writes its report, then exits non-zero on blockers. Dependent checks report blocked, rather than pass. Validate includes effective publication state, JSON indexes where enabled, routes, anchors, downloads and prohibited resources.

Implement console, Actions-summary and PR renderers from one result contract. Include source commit, platform/policy versions and target. Prevent stale runs overwriting newer comments. Reporting failures are distinguishable from validation failures and never fabricate a pass.

**Acceptance:** local and CI stage results agree for identical inputs; failure fixtures still produce actionable reports; Kanban production enablement of Minionese fails independently of the selected preview ring; supplied PDFs and intentional fallbacks do not fail falsely.

## 8. E05 — Characterise existing Hugo behaviour without refactoring

Progress: [cross-consumer relocation evidence](baselines/2026-09-13-relocation/README.md) records 27 passing builds and nine passing repeat controls, unchanged PDF/path inventories, and existing alias/share-output variability. E05 remains open; the evidence does not approve module upgrades or waive functional/visual verification.

Record the deliberately structured multilingual behaviour before changing implementation. Build isolated, pinned copies of all three consumers against their existing dependencies and the mechanically relocated module. Keep production deployments untouched.

Cover every guide, edition and configured language, including intentional empty bodies, English fallback, PDF-only states, numeric language regions, RTL/CJK content, cascades, render/list exclusions, wrapper overrides, catalogues, category/creator pages, aliases, anchors and downloads. Record pre-existing differences between consumers' pinned module versions; upgrading a pin must not silently accept output changes.

Compare route and download inventories, rendered guide content and navigation, protected source/PDF hashes and representative visual snapshots for each distinct rendering state. A green Hugo build alone is insufficient. Baselines require review and must not be regenerated automatically to make a candidate pass.

**Acceptance:** every guide is represented in the regression matrix; existing behaviour and visual output are preserved through relocation/adoption; unresolved differences block acceptance. This package does not reorganise partials, replace availability heuristics, separate wrappers or introduce a rendering manifest. That proposed work remains in the later E14 stage.

## 9. E06 — Installable agent controls and independent enforcement

Generate consistent root `AGENTS.md` and `CLAUDE.md`, a canonical site policy document and Copilot instructions. Inventory nested overrides and validate references. Build agent-specific adapters from one governance contract; test each supported client/version/OS and distinguish Copilot CLI, cloud and IDE surfaces.

Contributor execution allows approved content writes and trusted build outputs, while policy, workflows, dependencies and protected content remain read-only where managed controls are installed. Shell, MCP and indirect write paths are part of the test scope. A maintainer profile is granted outside repository-controlled content.

Create a trusted required check using an approved evaluator/policy source that candidate commits cannot replace. Candidate schemas and manifests are untrusted data. Candidate build scripts may run only in an appropriately isolated, unprivileged build context. Privileged reporting/deployment must never execute them.

Administrator-managed installation is separate from project-file adoption. Document effective-policy diagnostics, version prerequisites and the limits of hooks. A repository file or PR label cannot grant privileged execution.

**Acceptance:** changing/deleting local tests or hooks cannot remove the required external check; protected edit attempts yield helpful feedback; the independent gate rejects policy weakening; managed settings are not claimed active merely because templates exist.

## 10. E07 — Packaging, shared workflows and adoption tools

Build a coordinated package and manifest containing exact component versions, Hugo module version, workflow SHA, checksums, schemas and toolchain requirements. Use versioned local caches rather than global PowerShell installations.

Implement installer/update operations with previewable diffs. Clearly distinguish regenerated platform adapters from starter wrapper files that become consumer-owned. Updates change the lock, native Hugo dependency, generated skill/control files and reusable workflow SHA together. Refuse unresolved conflicts.

Shared workflows provision tools, invoke the released Build module, transport artifacts and call deployment actions. Consumer workflows contain triggers, minimum permissions, inputs and explicit secret mappings. Keep cleanup and update workflows shared too. Platform self-build/release workflows remain distinct from consumer workflows.

Prepare the rename runbook with literal old/new references, required-check names and workflow ownership. Test release packaging privately in artifacts/draft form without exposing an incomplete consumable release. Establish the first release number from existing history; example versions in the proposal are not reserved tags.

**Acceptance:** a fresh consumer fixture can restore the package, build, validate and use installed skills; cached rebuild works without freshness access; missing/corrupt assets fail; workflow and lock identities cannot drift unnoticed.

## 11. E08 — Repository rename and first preview release

### Before the rename

- Confirm `nkdAgility/OpenGuidePlatform` remains available and record the original repository ID.
- Finish and review the platform migration candidate. Build the new canonical module identity using an explicit development replacement or local test fixture; such replacements are forbidden in consumer production locks.
- Export required configuration metadata and back up Git refs. Record historical module versions used by each consumer and their source hashes.
- Pre-stage remote-reference changes in the three consumers. Known reusable-workflow callers need explicit updates because GitHub Actions does not redirect renamed workflow repositories.
- Ensure the existing module's old published versions have a tested clean-cache resolution path after rename, or prepare a concrete compatibility distribution plan before proceeding.
- Avoid concurrent platform releases during the cutover. Do not indiscriminately cancel consumer builds that are using already pinned artifacts.

### Rename operation

1. Rename the existing GitHub repository from `HugoGuides` to `OpenGuidePlatform` under the same owner.
2. Confirm the repository ID, history, default branch, tags and release assets are preserved; verify issues, PRs, access, rules, integrations and settings instead of assuming every external integration follows the rename.
3. Update local remote URLs and automation references to the new canonical URL. Update badges, documentation, issue links where appropriate, module declarations, example imports and applicable action callers.
4. Set the new Hugo module declaration to `github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides` for its initial pre-v2 line. Publish corresponding tags under `system/OpenGuidePlatform.Hugo.Guides/v...`.
5. Update the example site's own module identity. Remove migration-only local replacements from consumer release paths; allow documented platform-development replacements only in the reference development configuration.
6. Rename the local checkout directory separately from the GitHub repository rename. Close or relocate active processes/worktrees first, check the resolved source/destination, and update saved projects/scripts. Do not rename the directory underneath an executing build. The local folder name is not a release gate.
7. Run the platform build and verify new module resolution in a clean cache without local replacements.
8. Test old consumer module imports at their historical pinned versions in a clean cache. Check direct Git resolution as well as the supported Go proxy path; existing caches are not proof of compatibility.
9. Publish the complete preview release after its assets and manifest pass verification. Bind the new module tag and reusable workflow revision to the tested source.

Do not immediately create a replacement repository at the old name: that can invalidate the redirect relied on by historical consumers. A legacy compatibility repository, if needed, requires a deliberate migration design and fresh-cache tests.

### Rename acceptance and recovery

**Acceptance:** new canonical module/package/workflow references work; old published consumer pins remain resolvable through the documented compatibility path; repository integrations and required checks are healthy; no published website has been redeployed merely because the platform was renamed.

If rename validation fails before new consumers adopt the platform, stop release publication and repair the reference/integration problem. Renaming back is a possible operator-controlled recovery only after checking name availability and both directions of reference impact. After adoption, prefer forward repair and consumer rollback to known-good pins; do not assume a second rename is harmless.

## 12. E09 — KanbanGuides pilot

Create an adoption branch from current main. Install the preview platform, add site policy and lock, and replace the embedded workflow implementation with shared callers. Update imports and module pins atomically. Install the seven released skills and agent adapters; only then remove duplicated scripts/instructions.

Keep both guides, translations, PDFs, contributor data and bespoke wrapper behavior in KanbanGuides. Configure historical fallbacks explicitly. Enforce permanent Minionese prohibition at Prepare, artifact validation and production verification. Preserve language-scoped aliases and download URLs.

Repair CODEOWNERS and conflicting agent guidance. Change rulesets to the final required check identities during the workflow cutover, with continuous protection from the trusted gate. Test fork PR behavior without secrets.

Deploy the adoption PR to its preview environment and verify the exact commit, guide routes and downloads. A platform preview adoption does not itself authorise publishing that platform version to production.

**Acceptance:** full local/CI checks pass; intentionally enabling Minionese fails the trusted gate; preview matches declared publication; wrappers and guide content remain intact; no stale generated configuration or duplicate skill implementation remains.

## 13. E10 — the-safe-delusion adoption

Create a maintainer-scoped migration branch. Resolve the untracked instruction document and existing override discrepancies through an explicit policy review. Preserve `safe-decision-makers/**` source/PDF hashes and approved guide rendering.

Retain its homepage, editorial wrapper pages, shortcodes, navigation and styling. Adapt those integrations to supported platform contracts. Configure the supplied audited PDF as protected, with generation and edition changes unavailable to the default contributor profile.

Upgrade the older module through a reviewed migration; fix outdated build configuration as part of that explicit diff. Use shared build/workflows without importing Kanban's multilingual wrapper requirements.

**Acceptance:** protected source/PDF bytes match baseline; expected headings and source-note anchors work; wrapper navigation and bespoke presentation pass representative browser checks; no editorial content is rewritten by the adoption tool.

## 14. E11 — ScrumGuide-ExpansionPack adoption

Inventory every guide and its effective production/preview behavior. Declare the core/extension relationship and per-guide eligibility, preserving existing cascades until equivalent policy is proven. Keep categories, creators, markup behavior and bespoke catalogue presentation local.

Install platform tooling, compatible Hugo dependency, skill/control adapters and thin shared workflow callers. Preserve partial translations and PDF-only states. Maintain current Klingon exclusion; add permanent prohibition only if explicitly approved.

Inspect the legacy duplicate-key deployment workflow through a maintainer-owned change, determining its actual GitHub state before retiring it. Preserve unrelated discussion, stale-issue and wiki workflows. Ensure there is one intended deployment route rather than competing deployment implementations.

**Acceptance:** no excluded extension appears in output or catalogues; core/extension categories and creator pages work; translated and fallback states are accurate; current public URLs and PDF paths remain valid.

## 15. E12 — Stable release and site promotion

Require compatibility evidence from all three adoption previews and the reference fixtures. Select the stable platform version, publish its complete immutable release and matching Hugo tag, and run clean-install verification. Version metadata changes between preview and stable require the relevant package/build tests; do not claim untested byte identity.

Open separate consumer update PRs moving from preview pins to the stable tested combination. Merge and release each site through its own approved process. Rebuild stable-target artifacts where required, validate them, and deploy only those artifacts with their recorded identity.

Post-deployment Verify checks exact commit/ring/platform version, required routes and page identity, downloads, redirects, language indexes where configured, and consumer-specific exclusions. Use bounded propagation retries. Report a failed verification as a failed deployment outcome with the known-good recovery action.

**Acceptance:** all three sites use the stable platform and shared workflow revision, production verification succeeds, and each has a documented rollback artifact or source/lock combination.

## 16. E13 — Finish adoption and ongoing updates

Remove transitional duplicated build logic only after all known callers are migrated. Preserve Hugo compatibility adapters and supported override paths until E14 has verified their replacements and the promised compatibility window ends. Keep historical release tags intact.

Configure a narrowly scoped updater identity to propose new platform versions to consumers. Routine builds use their lock and only warn about newer releases. Record installation provenance and generated-file hashes. Diagnose freshness lookup failure as unknown rather than success.

Move the accepted proposal and this plan into platform architecture documentation, link consumer documentation to the canonical location and retain a migration reference where useful. Document developer setup, publishing operations, skill usage, release policy, managed-agent rollout, incident recovery and ownership.

**Acceptance:** a new maintainer can adopt a fixture site from the public release, update it through a reviewable diff and recover from a failed update using the documented commands.

## 16A. E14 — Refactor Hugo module contents last

Build and verify everything else first: repository/module relocation, shared build and validation, packaging, skills, agent controls and workflow integration. Verify those changes with the three guide sites in isolated builds and previews while preserving the module's existing internals. Production deployment is not required before this stage.

Then return to the module refactoring already proposed in the architecture document: capability organisation, separation of inventory and presentation, guide/translation availability, wrapper integration, the publication contract and demo-specific configuration. This keeps the original work visible and sequenced later; it does not introduce a separate hardening programme or additional mandatory deliverables.

Use the working pre-refactor builds as the comparison baseline. Verify changes across all guides in the three sites before confirming the refactor, preserving the deliberately structured multilingual behaviour, functionality and visual output. Keep the work on branches and PRs with preview verification; do not change deployed production sites as part of that verification.

**Acceptance:** the proposed module refactoring is verified against the working builds of all three sites, with no unexplained functional or visual differences.

## 16B. Implementation follow-ups within the existing work packages

These are explicit acceptance tasks discovered or clarified during implementation. They supplement the original entries, not a new migration or Hugo hardening programme. Completed implementation is distinguished from remaining acceptance. Questions about alternatives do not authorise changes.

### E03 — Publishing operations and distributed skills

- [x] Complete wrapper/i18n creation and reviewed reconciliation, then verify the distributed skills and Prepare consume the same effective translation evidence. See the E00–E03 reconciliation above; PDF diagnostics/fingerprints and generated replacement/cache operations are already implemented. Real consumer adoption is not an E03 prerequisite.
- [x] Preserve supplied/protected PDFs, PDF-only editions and intentional English fallback in Core operations and declared-download validation. PDF receipt orchestration remains E04; consumer-specific proof remains E05/E09–E11. Do not regenerate supplied publications to make checks pass.

### E04 — Build validation and actionable reporting

- [x] Map each policy-declared download from its source guide/edition location to its actual published artifact path and pass those expectations into validation. Add negative tests for missing declared downloads and prohibited downloads outside language-prefixed directories.
- [x] Bind saved Prepare evidence to all relevant assessed content, configuration and tool inputs. Reject reuse after a local assessed input changes, even when commit, target and policy digest are unchanged; include a regression test across separate Prepare and Build invocations.
- [x] Complete required heading-anchor validation alongside page, asset and download checks. Static checks passed in committed sample CI; JavaScript-created consumer anchors remain an E05 adoption disposition.
- [x] Deliver structured Prepare assessments for same-repository PRs in an isolated data-only reporting job; include blocked findings and repair guidance, with stale-run and delivery-failure tests. Real PR #35 delivery is recorded below. Fork delivery and independent authority remain E06; a deployment-link comment is not the Prepare report.
- [ ] Integrate current-artifact browser evidence for declared runtime anchors; do not waive static failures solely because an older baseline passed.
- [ ] Collect/persist approved PDF environment and generation receipts during build integration without regenerating supplied or protected publications.
- [ ] Preserve only the frozen, existing legacy `/download/`, `/downloads/` and `/translationsdirectory/` alias declarations during affected consumer adoption, including existing language variants. Do not extend them to new languages or introduce a blanket collision exemption.
- [x] Validate rendered guide bodies and reject unresolved rendered translation placeholders in the sample.
- [x] Verify Japanese edition selection and declared English fallback, and Minionese preview content with production exclusion in sample builds.

### E05 — Cross-consumer equivalence

- [ ] Finish semantic, route, anchor, download and representative visual comparisons across every guide and distinct language/edition state in the three real consumers. Existing relocation evidence (27 builds and nine repeat controls) and sample checks do not complete this acceptance.
- [ ] Review unexplained differences against each consumer's own pinned dependency before accepting any module upgrade; do not regenerate baselines automatically.

### E06 — Agent controls and trusted enforcement

- [x] Make root `AGENTS.md` and `CLAUDE.md` real symbolic links to `.agents/agents.md`; verify identical resolved bytes in a fresh Windows clone.
- [x] Document Windows symbolic-link prerequisites and `git config --global core.symlinks true`; apply the global setting on the maintainer's system.
- [ ] Complete and test managed Codex, Claude and GitHub Copilot controls on the supported client/OS surfaces, including indirect shell/MCP writes and nested overrides.
- [ ] Establish administrator-owned contributor/maintainer permissions and an independent required gate that candidate code cannot replace or weaken.
- [ ] Verify that privileged PR reporting and deployment never execute untrusted candidate code. Instruction files and installed templates alone are not enforcement evidence.

### E07 — Consumer distribution and shared workflow acceptance

- [x] Provide the same remote command for installation and update: `irm https://raw.githubusercontent.com/nkdAgility/OpenGuidePlatform/main/bootstrap.ps1 | iex`. Real branch-URL install/update tests passed; the main URL becomes available after merge.
- [x] Publish bootstrap as a standalone release asset, outside the platform ZIP; perform release discovery, integrity checks and package retrieval internally.
- [x] Test fresh installation, update, cached restore, generated consumer build adapters and conflict refusal. Keep the current installation record explicitly preview-only until the complete release contract is implemented.
- [ ] Complete coordinated release metadata and adoption updates for the native Hugo dependency, component versions, schemas, toolchain requirements, workflow identity and generated skills/controls. Immutable provenance may record source commits; action references must use version tags with no unnecessary version restriction.
- [x] Validate the corrected publication gate: `main.yaml` builds/packages, directly calls the shared guide-site workflow for every sample stage using the build artifact ZIP URL/checksum/version/commit, then publishes the same assets only on success. Remove `sample-main.yaml`; retain published-release resolution for ordinary consumers. Committed and verified by successful runs 34764729959 and 34766032512. Release remains restricted to main pushes; PR validation does not publish.
- [x] Run distinct Prepare, Build, Validate, Deploy and Verify jobs with one selected target per sample run. Restore released assets rather than building the platform inside the consumer workflow.
- [ ] Exercise the shared close-PR workflow against an authorised disposable preview and confirm the intended environment is removed. PR #35 cleanup is configured but has not been exercised.
- [ ] Reconcile existing consumer-owned files explicitly during adoption; do not overwrite them or claim a clean fixture installation proves migration of existing sites.
- [x] Keep human README installation, update, local build/serve and sample URL instructions aligned with the shipped interface. Serve remains a stage of the root build entry point.

The question about renaming the shared workflow to `OpenGuidePlatform.yaml` has not authorised a rename. Its current filename remains `guide-site-build.yaml`.

### E08 — Remaining identity and publication cutover

- [x] Rename the GitHub repository to `nkdAgility/OpenGuidePlatform` and update the local origin URL.
- [x] Publish and verify a platform preview release and deploy the sample preview through the shared workflow.
- [ ] Publish the canonical native Hugo module `github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides` with matching nested module tags and coordinated package/workflow provenance.
- [ ] Remove migration-only packaged Hugo replacements from consumer release paths, including production-target builds; verify canonical native imports in a clean cache.
- [ ] Verify historical consumer pins through both supported proxy and direct Git resolution after the rename, and finish the integration/reference cutover audit.
- [ ] Update the example module identity and remaining canonical references. Rename the local checkout separately when safe; its folder name is not a release gate.

### E09–E11 — Consumer-specific adoption checks

- [ ] Adopt each site on its own branch and PR, preserving its bespoke wrapper, any number of guides, published content and supplied/protected PDFs. No deployed consumer site has been adopted by the current platform/sample work.
- [ ] For KanbanGuides, prove permanent Minionese exclusion through trusted policy, artifact downloads and deployment verification while preserving the existing legacy aliases only.
- [ ] For the-safe-delusion, resolve instruction/policy ownership and verify protected guide/PDF hashes and approved rendering.
- [ ] For ScrumGuide-ExpansionPack, preserve core/extension cascades, multilingual/PDF-only states and current Klingon exclusion; a permanent prohibition requires a separate policy decision.

### Maintainer verification and action points

- **E01/E06:** permission changes and GitHub administrative configuration are excluded by the maintainer. Continue implementing and testing repository controls through E08; record independently installed enforcement as pending external action, without making it a prerequisite for repository implementation.
- **E09/E10/E11:** review each consumer's exact preview and functional/visual comparison before accepting adoption. Routine implementation and local verification continue without an extra permission gate.
- **E12:** authorise stable promotion and each production deployment separately; preview adoption is not production permission.
- **E13:** establish updater identity and operational ownership; keep updates reviewable and freshness lookup failures explicitly unknown.
- **E14:** accept the original deferred internal refactoring only after comparison against the working adopted builds of all three sites. It follows verified adoption previews and does not depend on production promotion or handover.

### Recorded preview evidence

- Source: `8d1822027afde92a951f09bf070dab0819cb5235`.
- [Platform build/release](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34759406727) and [five-stage sample preview](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34759407030) passed.
- [Preview release v0.5.3-PullRequest0035.139](https://github.com/nkdAgility/OpenGuidePlatform/releases/tag/v0.5.3-PullRequest0035.139).
- Local evidence: 129 Pester tests, 19 contract checks and seven distributed-skill checks passed; sample preview validated 44 HTML pages/986 local links, production validated 29 HTML pages/666 local links.
- All 44 deployed HTML pages and 74 other public files matched the CI artifact. Representative browser inspection covered Japanese fallback and Minionese content; this is not a complete cross-consumer visual regression suite.
- No consumer production deployment, native-module cutover or independent-governance acceptance is claimed by these results.

## 17. Verification matrix

| Scenario | Required evidence |
|---|---|
| Module relocation | Source/resource move manifest plus functional and visual equivalence across all three consumers |
| Later Hugo module refactor | Compare every guide across all three sites with the working pre-refactor builds |
| Repository rename | Same repository identity/history, working new refs, historical clean-cache imports |
| Bespoke wrappers | Approved route/anchor inventory and representative browser comparisons per site |
| Multilingual work | Wrapper and guide states reported separately; numeric region, RTL and CJK fixtures |
| Protected content | Baseline source/PDF hashes unchanged; rendering contract checked |
| PDF generation | Opens successfully, contains pages, expected fonts/layout on representative fixtures |
| Publication exclusion | Negative tests for language, edition, guide cascades and downloadable resources |
| Governance tampering | Candidate modification/removal of checks cannot satisfy the independent gate |
| Package update | Lock, module tag, workflow SHA and generated adapters updated together |
| Failure reporting | Actionable report survives Prepare failure; missing reports never pass |
| Fork contribution | Validation runs without secrets; unavailable preview deploy is handled explicitly |
| Production deployment | Validated artifact identity matches deployed commit, ring and platform |

## 18. Rollback boundaries

| Failure | Recovery |
|---|---|
| Mechanical source move regression | Revert the relocation PR; no consumer migration has occurred yet. |
| Preview platform defect | Publish a new preview version; retain immutable old assets. Revert consumer adoption pins if needed. |
| Consumer migration regression | Revert its coordinated adoption/update PR and deploy its known-good artifact. Restore corresponding required-check configuration through a controlled change. |
| Production verification failure | Stop further promotion, restore the known-good artifact, and verify recovery before resuming. |
| Managed agent policy blocks valid work | Administrator corrects/version-rolls-back managed policy; do not instruct contributors to bypass controls. |
| Security flaw in a platform release | Prevent further adoption/deployment of the affected version through trusted policy and issue a fixed release; assess already deployed artifacts. |
| Rename/reference failure | Follow E08 recovery; do not recreate the old repository name or rewrite tags as an improvised fix. |

No rollback may silently re-enable Minionese or remove mandatory production protections. Baseline artifacts must be assessed against non-negotiable policy before they are accepted as recovery candidates.

## 19. Completion checklist

- [x] E00 Baselines refreshed and recorded, with known findings and explicit later verification/recovery gates.
- [ ] E01 Contracts and policy ownership agreed.
- [x] E02 Shared source/example content moved with provenance.
- [x] E03 Core operations and seven skills extracted and tested.
- [ ] E04 Local build, validation and reports implemented.
- [ ] E05 Existing multilingual behaviour characterised across every guide; relocation/adoption preserves output.
- [ ] E06 Agent adapters and independent enforcement verified.
- [ ] E07 Distribution, updater and shared workflows tested.
- [ ] E08 Repository renamed and first preview release verified.
- [ ] E09 KanbanGuides preview adoption accepted.
- [ ] E10 the-safe-delusion preview adoption accepted.
- [ ] E11 ScrumGuide-ExpansionPack preview adoption accepted.
- [ ] E12 Stable platform and consumer production releases verified.
- [ ] E13 Adoption transition documentation, update automation and operational handover complete.
- [ ] E14 Proposed module refactoring done after the other work builds successfully, and verified across all guides and sites.

E01 version-tag reconciliation is implemented: the contract separates the version reference from source provenance and permits broad version labels. Final protected-policy ownership decisions remain open; installing independent enforcement belongs to E06. E03 is now complete: the gaps recorded in the earlier E00–E03 audit were implemented and verified; see the closure entry below. E00 and E02 are complete. Schema and skill metadata checks do not imply later-stage enforcement or full skill acceptance.

## Execution log — continued reconciliation

- E01: reconciled workflow version tags with separate commit provenance in ADRs, lock schema and contract fixtures. Broad version labels are accepted; SHA action references are rejected. Owner configuration remains E06 work; no candidate file grants authority.
- E07: added Actions read permission to generated consumer callers, required by the shared workflow's artifact-restoration interface. The direct sample/publication chain passed in GitHub run 34761323204; subsequent commits require their own CI evidence.

### E03 acceptance candidate — reviewed wrapper operations and common readiness

Implemented Set-GuideWrapperTranslation for reviewed wrapper Markdown, catalogue and selected-language configuration changes. The distributed translation skills now read the same Prepare report as CI. Local validation passed: 151 tests in the shared working tree, 26 contract checks, seven skill checks, real Hugo catalogue probing, packaging and package verification. A disposable sample copy successfully added an es-419 wrapper language through the new configuration/content/catalogue operations and passed real Hugo Prepare.

An initial Windows replacement attempt failed without changing the target; isolated replacement checks and a retry using separately captured candidate text and reviewed hash succeeded. The operation fails closed on replacement errors; file access by other processes is not bypassed. Core regression tests verify prior bytes survive staging failures.

The implementation addresses the reconciled E03 gaps; its package checkbox remains open until the committed candidate passes CI. Real consumer adoption and E04 PDF-receipt orchestration are not E03 prerequisites. Concurrent workflow naming edits are outside this E03 change.
### E03 closed against the reconciled criteria

Commit `d953f2f71c7e3cbee8f6dc9ff1cadddde247eee7` passed [CI run 34762682088](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34762682088): platform build/package plus sample Prepare, Build, Validate, Deploy and Verify all succeeded. Release was intentionally skipped by the current main-only publication condition. Together with the recorded real wrapper/Persian PDF checks and Core regression tests, this closes the original E03 criteria. The older unchecked audit sub-items describe the pre-implementation state and are superseded by this closure. E04 receipt orchestration, E06 independent enforcement and consumer adoption retain their own gates.
### E04 Prepare freshness guard

Local validation passed with 160 tests and 26 contract checks. A real disposable sample run proved that changing content after Prepare, with the same commit and policy, blocks a separate Build; restoring the assessed bytes permits Build and standalone Validate. Inputs include wrapper/guide files, configuration, policy, selected version, platform runtime, relevant environment settings and build-tool fingerprints. Validate checks file evidence without needing Hugo installed. This closes the stale local Prepare-input finding; E04 remains open for downloads, anchors, PR reporting and remaining stage acceptance. CI verification of the committed guard follows.
### E04 download publication validation

Implemented reviewed `publishedPaths` for each declared source download, Prepare findings for absent mappings/source files, and artifact checks for required paths and unchanged source bytes. PDF-only/fallback resources remain valid. Excluded resources are checked throughout the artifact by mapped path, filename and source digest, with explicitly allowed shared fallback paths preserved. Post-deployment Verify requests exact forbidden download URLs, including paths outside language prefixes.

Validation: 170 tests, 26 contract checks, seven skill checks, full platform packaging, workflow lint and real Hugo preview/production builds of a disposable sample with an edition-relative synthetic PDF resource mapped to its public path. This tests artifact publication/bytes, not PDF rendering. Consumer published content and Hugo internals were unchanged. The generated policy must record existing public paths during adoption; no guessed route migration is implied.

Freshness CI run 34763082733 exposed a Prepare-only YAML dependency incorrectly required by the Build fingerprint check. Commit d2ccb9a removes it and adds a regression; its CI result remains required. Shared stage names from the concurrent naming correction are preserved and tested independently of target names.
### E04 committed CI verification and anchor checks

Commit `1656159a95b02468928a2d759c97540c481df673` passed [CI run 34763565169](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34763565169), including platform packaging and sample Prepare, Build, Validate, Deploy and Verify. This verifies both the Build fingerprint dependency repair and download publication checks. PR release publication was correctly skipped. The active follow-up checklist now reflects those results rather than retaining stale unchecked entries.

Anchor validation now checks same-page and cross-page HTML fragments, encoded Unicode IDs and legacy named anchors. It excludes PDF viewer fragments, text-fragment navigation and false targets in data attributes, form names, comments or script text. Missing anchors produce page/target findings in the existing validation report. Local acceptance passed: 173 tests, 26 contracts, seven skills, platform packaging and both real Hugo sample targets. Committed CI verification follows before closing the anchor follow-up.

These are static HTML checks. Existing JavaScript-created destinations in consumer wrappers still need the E05 browser evidence and an explicit treatment before adoption; this implementation does not declare those existing links broken or waive them. E04 remains open for trusted PR reporting, PDF receipts and remaining publication/index/alias cases. No deployed consumer site or Hugo module internals changed.
### E04 root Prepare failure reporting

The public root build now routes policy/configuration/tool setup failures through the existing blocked assessment contract before throwing. Missing policy and invalid base URL regressions exercise `build.ps1` itself, verify JSON/Markdown/Actions summaries, keep dependent readiness unknown and prove no reusable Prepare inputs are emitted. This closes a gap that direct tests of the lower-level Prepare script did not cover.

Local validation passed: 175 tests, full platform packaging and both sample targets. Existing evidence directories are still refused rather than overwritten. Failures before a safe output directory/source identity is available, and a change detected during Prepare's final fingerprint check, remain explicit errors; this change does not claim every possible infrastructure failure can produce a stored report. Committed CI verification follows.
### E04 assessment delivery isolation and verification

Anchor commit `cb02519053e1de4826b657c50548a6feaab86599` passed [run 34763960762](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34763960762). Root failure-report commit `0b14231008c725cde596751adc83887351fb194d` passed [run 34764164833](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34764164833). Both completed platform packaging and all five deployed sample stages; PR Release was skipped as required.

Prepare now retains a small report-only artifact. An ancillary Prepare report job uses the existing common Markdown output as data through the GitHub API adapter. It has no checkout or candidate/package execution. Guide-site build jobs remain read-only; the platform build job now explicitly has read-only repository permissions as well. The adapter checks commit/target/stage identity, current PR head twice, immutable run markers, duplicate/conflicting delivery and comment size. Failed Prepare runs can still deliver their recorded findings. Delivery failures are distinct and cannot change the assessment outcome. Same-repository PRs receive comments; fork comments remain deferred to trusted cross-run reporting in E06, with their artifacts retained meanwhile.

Local validation passed with 177 tests, 26 contracts, seven skills, platform packaging and workflow lint. Adapter tests execute the actual workflow JavaScript with fake GitHub responses for current/blocked/stale/duplicate/conflicting/missing/API-error cases and prove report text remains data. Real PR delivery is the next committed CI check. The reporter uses the existing immutable per-run strategy; it does not turn mutable candidate workflows or policy into independent enforcement.
### E04 real PR report and consumer caller reconciliation

Run `34764554228` delivered [the actual Prepare assessment to PR #35](https://github.com/nkdAgility/OpenGuidePlatform/pull/35#issuecomment-5654087279), including all twelve sample guide/edition/language rows, Japanese fallback, wrapper runtime evidence still pending and the module-freshness warning. The reporter job succeeded without candidate code execution. The sample's Go file does not declare a released native module because it currently consumes the packaged overlay; freshness remains unknown rather than fabricated. Coordinated native module identity remains E07/E08.

The generated consumer caller now passes `pull-requests: write` only to its shared workflow call, so the shared isolated reporter can request that permission. The consumer's workflow-wide default stays read-only and shared build jobs do not inherit reporting authority. An additional caller regression passed; local platform validation totals 178 tests. The original E03 follow-up text has been reconciled so a completed Core/download task no longer appears unchecked under the closed stage, while PDF receipt integration is explicitly listed in E04.
### E04 latest combined CI and E05 navigation evidence

Commit `f13fd47d270b62bc8e5db22871c7ce87d706f1e2` passed [run 34764729959](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34764729959): platform build/package, sample Prepare, Prepare report, Build, Validate, Deploy and Verify all succeeded. Release was skipped on the PR. This verifies the reporting implementation and its packaged consumer caller changes together; the earlier reporting run was superseded after successful comment delivery and is not claimed as a completed run.

E05 now has [static navigation evidence across all 27 retained consumer artifacts](baselines/2026-09-13-relocation/README.md#additional-static-navigation-characterisation). All 6,966 artifact hashes were reverified; exact original/relocated findings match in all nine comparisons. Existing missing-resource/redirect/runtime-anchor findings have explicit follow-up categories rather than blanket exemptions. E05 remains open for remaining semantic and representative visual/runtime acceptance.

Browser accessibility inspection of sample version `0.5.3-PullRequest0035.154` confirmed `/ja/guide1/` displays edition 2025.5 with the explicit English-fallback notice and body, and `/min/guide1/` displays its translated body and matching heading/TOC targets. This is a limited rendered-page observation, not a screenshot comparison, a full interaction test or acceptance of consumer-site visuals.
### E04 final input snapshot before report publication

Prepare now finalizes the assessed input fingerprint before rendering or saving its assessment. If concurrent changes invalidate the snapshot, it records `PREPARE_INPUTS_UNVERIFIED`, sets outcome to blocked and retains independent findings already collected. The root build only persists reusable input/tool evidence after this assessment succeeds. This resolves the earlier explicit limitation where the final fingerprint guard could throw after a passing report had been written.

A regression verifies both the concurrent-edit blocker and an independent missing-wrapper-file finding remain in JSON/Markdown/Actions output, with no passing summary. Local validation passed: 179 tests, platform packaging and both real Hugo sample targets. Documentation/evidence commit `87418fa1186552c48bdd230383ef2927abefaece` also passed [run 34765135991](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34765135991). The new finalization implementation requires its own committed CI verification.
### E05 selected browser replay and E01 ownership decision

[Runtime-anchor evidence](baselines/2026-09-13-relocation/README.md#selected-runtime-anchor-verification) now distinguishes Safe Delusion's working JavaScript-created skip targets from its missing appendix destination and Scrum Planguage's missing numeric anchors. Fourteen original/relocated page observations passed the diagnostic replay; existing missing IDs remain findings, not test successes. The replay only used retained raw artifacts and blocked external requests. E05 still requires the remaining guide-state and representative visual/network evidence; E04 must integrate current-artifact browser checks rather than exempt runtime anchors from static validation.

The full platform build passed after adding the replay helper (179 tests plus package verification). Prepare finalization commit `3e2a041f3b82c0f255a91736500c7a1fa5f5dec2` passed [run 34765465645](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34765465645), including the five sample stages and Prepare report; Release was skipped.

[The ownership decision is now concrete](protected-policy-ownership.md): existing technical CODEOWNERS and current repository roles support @MrHinsh as protected technical/publication-policy owner across all three consumers, while preserving editorial ownership. E01/E06 remains open for that explicit decision and independently installed/tested enforcement. No collaborator permission or deployed consumer change has been made.
### Continuation through E08 — scope and deployment boundary

The maintainer instructed continuation through E08 and explicitly excluded permission and GitHub administrative configuration changes. Repository implementation and validation continue; no roles, rulesets, secrets, environments or other administrative settings are changed. E09–E11 consumer adoption and consumer deployments remain outside this continuation. An unchecked administrative acceptance item does not stop independent implementation work and must not be represented as installed protection.

The shared Validate job now runs the local deployment preflight without write permissions or hosting credentials and retains a deployment-only artifact. Deploy has no checkout, candidate package, PowerShell or candidate script execution. Its workflow-owned data adapter verifies source, target, passing assessment, complete file inventory, bytes and published identity before the hosting action receives credentials. Candidate data is never evaluated as code. This closes the packaged-script privilege exposure; a candidate-editable workflow still requires separately administered independent enforcement to become a tamper-proof gate. Local and committed CI evidence follow before acceptance.
### E06 deployment CI and E08 canonical identity candidate

Deployment isolation commit `21c181ff852a7a178ea2a3553d99af6e2f56a8dc` passed [run 34772689061](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34772689061), including Prepare/report, Build, Validate, Deploy and Verify. The platform build passed 181 tests; PR Release was correctly skipped. This is execution-isolation evidence, not proof that candidate-editable workflows constitute an independently required gate.

The canonical module declaration and reference-site import now use `github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides`; the reference site's own module identity also uses OpenGuidePlatform. No Hugo template, resource or multilingual rendering logic changed. Platform packaging and both sample targets passed locally. Candidate-development overlays cover canonical and historical imports so that pre-adoption characterization can continue; removal of overlays from released consumer paths remains open.

Packages now record coordinated native module path/version/nested tag/source, workflow repository/path/version/source, actual shipped component versions and minimum toolchain requirements. Package validation checks those identities against the extracted content and manifest. The main-only publisher creates the matching nested module tag before the GitHub Release, reuses only an identical existing tag and refuses conflicts or publication failures. No native tag has been published from this review branch. Actual canonical clean-cache restoration remains required.

[Historical module resolution evidence](baselines/2026-09-13-module-identity/README.md) covers six successful downloads: all three current consumer pins through isolated Go-proxy and direct-Git caches, with matching checksums. This closes the historical resolution check but does not close the broader E08 reference/integration cutover.
### E06 independent evaluator implementation and client limits

Added `OpenGuidePlatform.AgentControls/RepositoryGovernance/Test-GuideRepositoryGovernance.ps1`. It reads baseline/candidate Git object inventories without checkout or candidate execution and requires an external evaluator/policy plus independently supplied policy digest. Protected technical files and nested instruction overrides cannot be changed through candidate-owned approvals. Tests cover permitted editorial changes, modified build/wrapper files, deletion, nested overrides, candidate-owned/tampered policy and missing baseline evidence. Installing this as an independent required check remains external work excluded by the maintainer's current instruction.

Current official client documentation confirms that settings are not interchangeable across Codex, Claude and Copilot. Native Windows Claude sandboxing is unsupported; Copilot's Windows sandbox does not support per-path denies, and Copilot policy hooks fail open on timeout. These limitations are recorded in the distributed AgentControls README. No universal client enforcement or live client/OS bypass-test acceptance is claimed, and no machine settings were installed.

Canonical identity commit `9dc4ad6833ad032e30773c613db8092b9c19d92a` passed [CI run 34773094713](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34773094713), including all sample stages. Its canonical module also resolved through fresh direct/proxy caches using the committed pseudo-version; named release-tag acceptance remains pending main-only publication.