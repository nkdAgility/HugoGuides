# OpenGuidePlatform execution plan

Initial implementation: `codex/open-guide-platform`, merged PR #35. Adoption-readiness fixes: `codex/adoption-validation-fixes`, [PR #37](https://github.com/nkdAgility/OpenGuidePlatform/pull/37) (new branch from current `main`). The checklist below is the authoritative stage status. [Historical reconciliations and evidence](open-guide-platform-execution-history.md) preserve prior findings and acceptance decisions.

Companion: [architecture and adoption proposal](open-guide-platform-proposal.md).

## Active distribution follow-up

Approved after the initial E07 implementation: split consumer and platform engineering release packages while keeping one coordinated version; remove bootstrap from release/install assets; move adoption into its released PowerShell module; share restoration across local and Actions entry points. Installed consumers update with `./build.ps1 Update -ring preview`; remote bootstrap remains the first-install and recovery entry point. This supersedes the earlier single-ZIP distribution detail, without changing the E00–E14 stage scope.

- [x] Implement split packages, manifest dependencies and thin installation/build entry points.
- [x] Implement local self-update, conflict checks and retirement of an unchanged legacy bootstrap.
- [x] Complete full platform, package and sample acceptance: 276 tests passed; both packages validated; sample preview (119 files) and production (87 files) passed from the exact GuideSite ZIP. Workflow lock coverage passed for all four workflows. Local report: `.processing/platform-tests/da7039c8b0c143ecadd3ca82b79588e3/summary.md`.
- [x] Verify the branch CI candidate through deployed sample checks: commit `6496b4a`, [run 34839561829](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34839561829), passed platform Build and sample Prepare, Build, Validate, Deploy, Verify and PR report delivery. Release was correctly skipped on the PR. Publication and real released installation remain post-merge verification.

No guide-site adoption, Hugo internals, production promotion or GitHub administrative settings are changed by this follow-up.

## Active local CI parity follow-up

The user authorized closing the remaining CI gaps after distribution cleanup. Azure Pipelines and TeamCity execution verification is not required; the acceptance criterion is that build operations take explicit inputs and do not require GitHub context, except release access. No new provider configuration, permissions or consumer deployment is authorized.

- [x] Implement actual module-owned deployment, custom hosting adapters and complete guide-site execution through Verify.
- [x] Implement shared GitVersion calculation and dependency setup; retain GitVersion 5 compatibility for the existing configuration.
- [x] Implement complete platform execution with explicit sample deployment/publication, preserving candidate package identity and failure gates.
- [x] Separate source inputs from runtime package dependencies and keep GitHub context in workflow adapters.
- [x] Complete local regression and sample acceptance: 288 tests, both distribution packages, sample preview (119 files) and production (87 files) passed. Local GitVersion calculation and workflow lock coverage also passed. Evidence: `.processing/platform-tests/47ec229fab7a43ec9c5acd667f3327d3/summary.md`.
- [ ] Verify the changed Actions sample deployment adapter through live Verify.

## Outcome

Rename the existing public `nkdAgility/HugoGuides` repository to `nkdAgility/OpenGuidePlatform`, preserve its Git history and releases, move its reusable code into named `system/` components, and adopt the resulting platform in KanbanGuides, the-safe-delusion and ScrumGuide-ExpansionPack.

Each consumer retains its bespoke wrapper and guide content. The platform supplies guide rendering, publishing operations, validation, distributed skills, agent controls and shared GitHub workflows. The same supported build operations run locally and in CI.

This is an execution plan, not authorisation inferred to rename or deploy immediately. Repository names and locations below are the proposed targets; confirm availability and current ownership during preflight. No new GitHub repository is needed for the main platform.

## Current acceptance status

**Run boundary agreed 14 September 2026:** the initial platform implementation run was complete within its agreed scope. The user subsequently merged PR #35 and authorized a separate branch to assess and fix adoption-readiness findings and the two stale scan PRs (#33 and #34). The following work remains in the execution plan but is explicitly deferred outside this run:

- Further GitHub administrative and required-check changes (E08); no configuration changes are authorized by this follow-up.
- The trusted deployment boundary that prevents PR-controlled code from accessing Azure deployment credentials (E06/E08).
- Installation and live verification of managed Codex, Claude and Copilot restrictions on contributor machines, to be addressed during guide-site adoption (E06/E09–E11).

These are retained requirements, not completed acceptance or active requests for permission. Do not resume them merely because this run was previously instructed to close blockers. E06 and E08 remain unchecked. After the remaining E08 released-installation verification, the next adoption stage is E09, KanbanGuides. No consumer adoption, production promotion or Hugo internal refactoring is authorized by this status record.

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

The approved simplification pass is implemented and verified at `85c1db805ebfb78f2a621c4a00815c2582f949a8`: unused adapters removed; shared stages moved into the Build component; package identity validation consolidated; prepared inputs deduplicated; one current PR assessment per target; execution history separated. No Hugo internals or consumer repositories changed.

Acceptance: **216 tests**, package validation and both local sample targets passed. [CI run 34787509971](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34787509971) passed platform packaging and all five sample stages through live Verify; release was skipped. Actual reporting created current preview comment `5656678132`. Tests exercise its update, target isolation, stale-head refusal and delivery failure paths.

A fresh installed sample fixture also passed preview, production, cached restore with GitHub access blocked and `GOPROXY=off`, and same-version update; all seven skills loaded. It consumed version `0.0.0-20260913224036-85c1db805ebf`, ZIP SHA256 `8e6a086498bb4d7a85eccb8430618e604d4e1a3064917b7da539f6c2ccee3848`. Only release download transport used local assets; native Go resolution, bootstrap and installed builds were real. No named release was published. Local evidence is retained in `.processing/simplify-installed-consumer-evidence.json`.

The only intentional duplication retained is verification before executing downloaded code: archive safety and checksum/source checks remain in standalone bootstrap and CI restoration. They cannot depend on unverified package code. Both then use the same packaged identity validator.

Remaining gates:

- **E06:** managed client/OS enforcement and an independently administered required gate are uninstalled/unverified. No permission or GitHub administrative changes are authorized. The recorded exception permits repository implementation through E08.
- **E07 / E09–E11:** fresh-fixture acceptance is complete; each existing consumer's file conflicts and deployment integration must still be reconciled in its own adoption PR.
- **E08:** the GitHub rename and initial coordinated preview publication are complete. PR #35 merged at `d859a32c8e3dbf4c154aef4a6c5079d6acd634d0`; [main run 34791229184](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34791229184) passed and published `v0.5.3-Preview.1`. Its nested Go module tag `system/OpenGuidePlatform.Hugo.Guides/v0.5.3-Preview.1` resolves to that same commit, verified with a fresh Go module cache. A clean installation from a named release remains outstanding. The new adoption-readiness fixes must pass review and preview validation and be included in a subsequent release before adoption uses them. E08 remains unchecked. No administrative or deployment-boundary changes are included in this fix branch.
- **E09–E11:** accept each exact consumer preview and functional/visual comparison before adoption. Safe Delusion's recorded old-module upgrade differences are accepted; the corrected Persian CSS capture is the valid baseline.
- **E12:** stable promotion and consumer production deployments need separate authorization.
- **E14:** internal Hugo refactoring remains after verified adoption previews across all three sites; production promotion is not a prerequisite.

### Actionable failure reporting

Platform test reports now carry explicitly authored **Why** and **How to fix** fields in local output and Actions summaries/annotations. The workflow-input failure is explained at the check rather than inferred from a low-level exception. Technical error/location remains supporting evidence. Unknown errors are explicitly undiagnosed; authoring explanations for every existing failure path remains ongoing work, not a completed universal diagnosis guarantee.

### Approved component naming

The component convention is `OpenGuidePlatform.<TechnologyOrEcosystem>.<Responsibility>`. Active code, import names, package checks and documentation now use `PowerShell.GuideSiteAdoption`, `PowerShell.AgentControls`, `Agents.GuideSkills` and `PowerShell.GuideSiteBuild`. `PowerShell.PlatformBuild`, `PowerShell.Core` and `Hugo.Guides` retain their names. No compatibility modules or duplicate component folders are retained. Historical baseline observations and execution history retain the names that existed when their evidence was collected.

### Platform and guide-site build modules

The approved two-module boundary is implemented: `OpenGuidePlatform.PowerShell.GuideSiteBuild` remains consumer-facing and independent; `OpenGuidePlatform.PowerShell.PlatformBuild` owns platform tests, packaging, release operations and sample acceptance against the produced ZIP. Both ship in the same package and version. Existing build/test/package scripts in `.build/` are forwarding entry points.

A shared loader supports local code, explicit directory/ZIP paths, installation locks, and specific/latest preview or production package resolution without changing a consumer lock. Production release selection is not authorization to publish or deploy production. Released Hugo dependencies must still match the selected release; overrides do not silently change consumer dependency files.

Local platform All now tests, packages, validates and runs preview/production sample builds from that exact package in fresh PowerShell processes. It does not deploy or publish. CI continues to run the independent deployment and live verification stages before publication. Complete local deployment parity, remaining baseline utility extraction, and macOS/Azure Pipelines/TeamCity verification remain open gaps; this module boundary does not mark those complete.

### PowerShell workflow consolidation — 14 September 2026

Bounded E04/E07 follow-up requested during PR #37: installed guide-site launchers restore the selected platform package and call `Invoke-GuideSiteBuild` from its Build module. Shared CI uses the same module from either the published release or the exact candidate ZIP. GitHub reporting and deployment data validation moved from inline JavaScript into that released module. YAML retains action wiring and single PowerShell calls. Root and component documentation describe the supported entry points.

The cleanup workflow now binds its environment directly to the closed PR number. The user specifically authorized adding `actions: read` to Deploy so it can restore the candidate artifact independently. No repository settings or additional write permissions changed. Independent trust enforcement remains deferred as recorded above.

- [x] Replace the JavaScript reporting/deployment harnesses with PowerShell behavioral tests for current/stale reports, failed delivery, artifact tampering and identity mismatch.
- [x] Isolate installer fixture modules and suppress fixture output in the real Actions summary. These caused failures and misleading summary identities in run 34832774246.
- [x] Local platform build: 257 tests and package validation passed. Preview sample: 119 files; production sample: 87 files. Both passed through the module entry point; production excludes Minionese.
- [x] Commit `978e32f48ac638089b4e5378b63c9796c41000be`: [CI run 34833482798](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34833482798) passed platform packaging, Prepare, Build, Validate, Deploy, Verify and PowerShell PR reporting. The sample consumed candidate `0.5.3-PullRequest0037.193`; Release was correctly skipped on the PR. This accepts the PowerShell consolidation only, not the deferred E06/E08 or consumer adoption gates.

### Adoption-readiness findings — 14 September 2026

The user authorized fixes on a new branch from latest `main`, including issues in the two stale scan PRs if still present. This is a bounded E07/E08 follow-up, not consumer adoption or E14 refactoring.

| Report | Assessment against merged main | Correction and regression coverage |
|---|---|---|
| PR #35 Copilot: automatic bootstrap `-WhatIf` switches branch | Confirmed; it creates a review branch before preflight and `ShouldProcess`. | Defer branch creation until all preflight checks pass and the operation is confirmed. Test automatic dry-run on main, failed preflight, and successful automatic installation. |
| PR #35 Copilot: navigation under a base path | Confirmed; `/docs/guide/` was looked up as `docs/guide/index.html`. | Strip the site base path before artifact lookup. Cover root/subpath URLs, relative links, Unicode, fragments, invalid encoded separators and sibling applications. Preserve existing extra-leading-slash handling. |
| PR #35 Copilot: JSON indexes under a base path | Confirmed; required entries and target files were incorrectly reported missing. | Use the same origin/base-path conversion; test required and forbidden routes and out-of-scope URLs. |
| PR #35 Copilot: runtime anchors under a base path | Confirmed with a real browser; page navigation dropped the prefix and resource interception retained it. | Join artifact routes beneath the base path and strip it for file lookup. A browser regression loads a real script and blocks sibling/external requests. |
| PR #33: contributor context | Still present at all three relocated call sites. | Pass the existing partial's expected author dictionary. Real Hugo rendering tests verify creator/contributor names and avatars on the homepage, guide details and creator partial. |
| PR #34: translation PDF fallback | Still selects the first shared PDF, potentially English for another language. | Match the requested language only. Real Hugo tests cover Persian, Japanese, French, Minionese, regional language codes, PDF-only English and an online Spanish translation without a PDF. Missing PDFs remain unavailable. |
| PR #37 Copilot: sample homepage override | Confirmed; the bespoke sample homepage retained a bare author-partial call even after the module was fixed. | Apply the same dictionary at that call site and test actual visible names in the overriding homepage with real Hugo. |
| Full production sample validation: `download_reference_status` | Existing status partials reference a missing shared catalogue key. | Add the English `Reference` fallback; keep the production language exclusions. |

The initial four Hugo rendering assertions fail against the original `main` templates and pass against the corrected templates. The changes port the stale PR fixes into current component paths; they do not merge the stale branches or modify deployed consumer sites. PR #34 also mentions a separate Spanish PDF path problem in KanbanGuides; that consumer-specific claim is not claimed fixed here and remains an E09 check against its exact adoption artifact. The additional catalogue entry is justified by the failing production acceptance build. The initial URL implementation also exposed existing double-leading-slash links; compatibility was restored without changing Hugo route generation.

Local acceptance after the sample-override review fix: **234 tests**, package verification, the Hugo translation probe and both full sample targets passed on this fix branch (Hugo Extended 0.164.0). Preview produced 119 files; production produced 87 files with Minionese excluded. [CI run 34792835067](https://github.com/nkdAgility/OpenGuidePlatform/actions/runs/34792835067) passed platform packaging and all five sample stages through live Verify at fix commit `672462efcf5d786d30dc3b6c521857611a29c4ee`. The [PR #37 preview](https://blue-field-06cea8c03-37.westeurope.6.azurestaticapps.net/) consumed the exact candidate package. Release was correctly skipped. This is fix-branch validation, not publication or consumer-adoption acceptance. The earlier 216/217-test evidence above remains historical; it is not acceptance of these follow-up changes. The sample-override follow-up also passed both local sample targets; current-head CI and review evidence is available on PR #37. Review, merge and a subsequent named release remain distinct from local validation.

Detailed additions to the original acceptance criteria remain in the [implementation follow-up register](open-guide-platform-execution-history.md#16b-implementation-follow-ups-within-the-existing-work-packages). They remain requirements, including publication/download exclusions, prepared-input freshness, dynamic anchors, PDF receipts, legacy alias limits, report delivery and cleanup. Moving their historical checkmarks here does not remove or reopen accepted work.

## 1. Scope and non-negotiable constraints

- Rename the existing repository rather than copy its current files into a new repository with unrelated history.
- Preserve all existing releases and tags. Never retag historical module versions or replace their assets.
- Move shared implementation and example content into OpenGuidePlatform. Keep published guide content and bespoke wrappers in their consumer repositories.
- Implement changes on feature branches with reviewable PRs and immutable preview candidates. Preview verification is not production deployment authorisation; repository rename remains an explicit administrative cutover.
- During migration and adoption, keep Hugo module internals unchanged apart from minimum relocation/identity updates and specifically authorized bug fixes. Preserve intended functionality and visual output; record each intentional correction with regression evidence. Broad internal refactoring remains E14.
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

Each work package should become an issue with this document's ID, and one or more bounded PRs. Mark a package complete only after its acceptance criteria are evidenced. The original implementation is preserved in merged PR #35; the current follow-up branch is recorded at the top of this plan.

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
system/OpenGuidePlatform.PowerShell.GuideSiteBuild/
system/OpenGuidePlatform.Agents.Integration/
system/OpenGuidePlatform.PowerShell.AgentControls/
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
| KanbanGuides `.agents/skills/*/SKILL.md` | `system/OpenGuidePlatform.Agents.Integration/` | Initially copy with provenance; retire consumer originals only after adoption installs replacements. |
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
