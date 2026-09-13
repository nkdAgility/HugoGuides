# OpenGuidePlatform execution plan

Implementation branch: `codex/open-guide-platform`, PR #35. The checklist below is the authoritative stage status. [Historical reconciliations and evidence](open-guide-platform-execution-history.md) preserve prior findings and acceptance decisions.

Companion: [architecture and adoption proposal](open-guide-platform-proposal.md).

## Outcome

Rename the existing public `nkdAgility/HugoGuides` repository to `nkdAgility/OpenGuidePlatform`, preserve its Git history and releases, move its reusable code into named `system/` components, and adopt the resulting platform in KanbanGuides, the-safe-delusion and ScrumGuide-ExpansionPack.

Each consumer retains its bespoke wrapper and guide content. The platform supplies guide rendering, publishing operations, validation, distributed skills, agent controls and shared GitHub workflows. The same supported build operations run locally and in CI.

This is an execution plan, not authorisation inferred to rename or deploy immediately. Repository names and locations below are the proposed targets; confirm availability and current ownership during preflight. No new GitHub repository is needed for the main platform.

## Current acceptance status

- [x] E00 Baselines refreshed and recorded, with known findings and explicit later verification/recovery gates.
- [x] E01 Contracts and policy ownership agreed.
- [x] E02 Shared source/example content moved with provenance.
- [x] E03 Core operations and seven skills extracted and tested.
- [x] E04 Local build, validation and reports implemented.
- [x] E05 Existing multilingual behaviour characterised across every guide; relocation comparison passed within the recorded baseline scope. Real adoption verification remains E09–E11.
- [ ] E06 Agent adapters and independent enforcement verified.
- [x] E07 Distribution, updater and shared workflows tested; real consumer conflict reconciliation remains E09–E11.
- [ ] E08 Repository renamed and first preview release verified.
- [ ] E09 KanbanGuides preview adoption accepted.
- [ ] E10 the-safe-delusion preview adoption accepted.
- [ ] E11 ScrumGuide-ExpansionPack preview adoption accepted.
- [ ] E12 Stable platform and consumer production releases verified.
- [ ] E13 Adoption transition documentation, update automation and operational handover complete.
- [ ] E14 Proposed module refactoring done after the other work builds successfully, and verified across all guides and sites.

Current work: the approved simplification pass removes unused adapters, moves shared build operations into the Build component, consolidates package identity validation, deduplicates input fingerprints, maintains one PR assessment per target and separates this plan from its history. Acceptance requires platform regression tests, install/update checks, both sample targets and committed preview verification. These checks are pending for this change; earlier green runs do not validate it.

Remaining gates:

- **E06:** managed client/OS enforcement and an independently administered required gate are uninstalled/unverified. No permission or GitHub administrative changes are authorized. The recorded exception permits repository implementation through E08.
- **E07 / E09–E11:** fresh-fixture acceptance is complete; each existing consumer's file conflicts and deployment integration must still be reconciled in its own adoption PR.
- **E08:** the GitHub rename is complete, but a complete coordinated named preview release, nested Hugo tag and clean released installation remain outstanding. Earlier preview releases predate the complete current manifest. PR #35 remains draft; obsolete required checks and review-thread requirements block merging. The current workflow lacks a merge-queue trigger. This simplification authorizes the reporting workflow edit, not administrative changes or an unrelated trigger change.
- **E09–E11:** accept each exact consumer preview and functional/visual comparison before adoption. Safe Delusion's recorded old-module upgrade differences are accepted; the corrected Persian CSS capture is the valid baseline.
- **E12:** stable promotion and consumer production deployments need separate authorization.
- **E14:** internal Hugo refactoring remains after verified adoption previews across all three sites; production promotion is not a prerequisite.

Detailed additions to the original acceptance criteria remain in the [implementation follow-up register](open-guide-platform-execution-history.md#16b-implementation-follow-ups-within-the-existing-work-packages). They remain requirements, including publication/download exclusions, prepared-input freshness, dynamic anchors, PDF receipts, legacy alias limits, report delivery and cleanup. Moving their historical checkmarks here does not remove or reopen accepted work.

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

Execution may deviate from this order when justified. Record the reason, affected work packages, scope, validation and effect on outstanding acceptance before acting. A deviation does not close unfinished criteria or authorize administrative changes or consumer deployments.

Each work package should become an issue with this document's ID, and one or more bounded PRs. Mark a package complete only after its acceptance criteria are evidenced. Current implementation is tracked in PR #35.

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

## 7. E04 — Implement Build, validation and reporting

Create the consumer stage interface described in the proposal. The bare command runs Prepare, Build and Validate with no deployment side effects. `-Versions` runs before importing dependencies that may be missing.

Build generates necessary configuration overlays and assessment reports in an output directory without changing Hugo rendering inputs or requiring a publication manifest, invokes the pinned Hugo toolchain, and packages the final hosting configuration in the actual artifact. Enforce native command exits, unresolved tokens, size limits and clean ring-specific output. Reject unsafe output/extraction paths.

Prepare collects all independent findings, writes its report, then exits non-zero on blockers. Dependent checks report blocked, rather than pass. Validate includes effective publication state, JSON indexes where enabled, routes, anchors, downloads and prohibited resources.

Implement console, Actions-summary and PR renderers from one result contract. Include source commit, platform/policy versions and target. Prevent stale runs overwriting newer comments. Reporting failures are distinguishable from validation failures and never fabricate a pass.

**Acceptance:** local and CI stage results agree for identical inputs; failure fixtures still produce actionable reports; Kanban production enablement of Minionese fails independently of the selected preview ring; supplied PDFs and intentional fallbacks do not fail falsely.

## 8. E05 — Characterise existing Hugo behaviour without refactoring

Complete: [cross-consumer evidence](baselines/2026-09-13-relocation/README.md) records 27 builds, nine repeat controls, all-page analysis and 284 matching viewport pairs across all 18 guides. Safe Delusion module updates are explicitly accepted. Known defects and offline visual limits are recorded in the closure below; deployed adoption remains E09–E11.

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

Build a coordinated package and manifest containing exact component versions, Hugo module version, workflow version tag and source provenance, checksums, schemas and toolchain requirements. Use versioned local caches rather than global PowerShell installations.

Implement installer/update operations with previewable diffs. Clearly distinguish regenerated platform adapters from starter wrapper files that become consumer-owned. Updates change the lock, native Hugo dependency, generated skill/control files and reusable workflow version tag and source provenance together. Refuse unresolved conflicts.

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
| Package update | Lock, module tag, workflow version tag and source provenance and generated adapters updated together |
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
