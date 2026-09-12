# OpenGuidePlatform: architecture and adoption proposal

Status: proposed for review. Prepared 12 September 2026. No platform implementation, repository rename, consumer migration or GitHub policy change has been performed.

Execution companion: [ordered work packages, repository rename and migration runbook](open-guide-platform-execution-plan.md).

## 1. Recommendation

Evolve HugoGuides into **OpenGuidePlatform**, a public platform for publishing guides, their editions and translations inside bespoke consumer-owned wrappers. All three consumers are the same architectural shape: a bespoke site wrapper around one, two or many guides. Distribute a coordinated release containing the Hugo module, PowerShell publishing/build tooling, agent skills and agent controls. Provide reusable GitHub workflows with thin consumer callers.

Use named components under `system/`, consistent with the Hub approach. Within components, organise around publishing capabilities and enforce dependency boundaries. Preserve the differences between the three consumers through explicit configuration and extension points.

The design fits all three sites **with six additions to the earlier proposal**:

1. Publication eligibility must apply to guides, editions and translations, not only languages.
2. Protected, externally curated content and supplied PDFs need an explicit preservation policy.
3. Editorial wrappers, core/extension relationships, categories and creator pages are legitimate consumer capabilities.
4. Existing template overrides must be inventoried and migrated to supported extension points; they cannot simply be prohibited or overwritten.
5. Translation readiness must be assessed against declared publication intent. A PDF-only translation, an English fallback and a missing required web translation are different states.
6. Each consumer owns its wrapper. OpenGuidePlatform supplies reusable guide capabilities and optional presentation primitives; it does not impose one site shell, navigation model or homepage on all three.

The number of guides is inventory data, not a reason to create three platform architectures. Site-specific editorial and publication requirements are policies and integrations around that same model.

Start with one Hugo module and two PowerShell modules. Keep skills and agent controls as separately identifiable components, even if all tooling initially ships in one ZIP. Do not create a module per UI component.

## 2. Evidence and assessment boundaries

This assessment reads local working trees, content, configuration, layouts, workflows and skills. It does not establish the latest remote state of the other repositories or certify their live deployments. No remote pull was performed for this assessment.

| Repository | Assessed local HEAD | Markdown files under `site/content` | PDFs under `site/content` | Pinned HugoGuides module |
|---|---|---:|---:|---|
| KanbanGuides | `cb991c4` | 88 | 35 | `v0.8.4` |
| the-safe-delusion | `64d25b6` | 10 | 1 | `v0.6.8` |
| ScrumGuide-ExpansionPack | `280f83d` | 140 | 31 | `v0.8.3` |
| HugoGuides | `980366a` | 24 example-site files | 0 | Local module development |

Counts are source inventory, not published page counts. The safe-delusion working tree contains an untracked `AGENTS.md`; its preservation instructions were considered, but should not be described as already distributed repository policy. The other three inspected working trees were clean before this document was added.

Hub's local reusable `channel-build.yml` and release implementation supplied the architectural precedent: shared workflows, a local build entry point, recorded Prepare findings, and coordinated release packages. Hub is a precedent, not a dependency OpenGuidePlatform should require.

An earlier clean KanbanGuides production build passed and excluded `/min/` and `*.min.pdf`. The other consumers have not been built or deployed during this assessment. Their older `minifyOutput` configuration and different dependency pins require explicit compatibility testing before migration.

## 3. Consumer fit

### KanbanGuides: bespoke wrapper around two guides

Two guide families: `the-kanban-guide` and `open-guide-to-kanban`. Edition directories currently cover The Kanban Guide 2020.7, 2020.12 and 2025.5, and Open Guide to Kanban 2025.7. English uses `index.md`; translations use language suffixes. There are history and translation wrapper pages, guide-specific contributor data and differently named PDFs.

Eight languages are configured: en, es-419, es-ES, fr, ja, fa, pl and min. Production configuration enables en, es-ES, fr, ja and fa. Minionese is explicitly disabled following PR #109, and must be permanently ineligible under the consumer's production policy.

Current historical web bodies for es-ES, fr, ja and fa are empty for the two older Kanban Guide editions. These need explicit fallback/publication declarations, not blanket failure or a misleading translated status. The seven existing publishing skills are a useful starting point, but contain hard-coded guide names and conflicting instructions.

**Fit:** full guide, edition, translation, attribution and download capabilities inside the KanbanGuides-owned wrapper. Consumer policy owns production eligibility, translation authority, discussion/review expectations and PDF filename compatibility. Its current reliance on module templates does not transfer ownership of its wrapper to the platform.

### the-safe-delusion: bespoke wrapper around one protected guide

One English guide, `safe-decision-makers`, edition `2024.8`, with a supplied PDF. Additional pages include brief, getting-out, objections, about and right-of-reply. The local agent instructions restrict ordinary work to the wrapper, protect the entire audited guide subtree and prohibit changing its rendering or dependency as part of wrapper work.

The site has a custom homepage, wrapper layout, source-note/editorial shortcodes, navigation, styling, breadcrumbs, robots and sitemap templates. Its source-note shortcode links claims to anchors in the guide, making anchor stability a concrete compatibility requirement.

Existing overrides and the local instructions do not fully agree: the instructions prohibit new module-shadowing layouts while the tree already contains several. Adoption must inventory the actual overrides and record which are intentional. It must not resolve that discrepancy by deleting them.

**Fit:** single-language publication is first-class. The platform preserves the audited guide and supplied PDF, validates wrapper-to-guide anchors, and offers explicit home/navigation/wrapper extension points. Scaffolding, edition creation and PDF regeneration are disabled for protected content unless a separately authorised maintainer operation permits them.

### ScrumGuide-ExpansionPack: bespoke wrapper around many guides

Fifteen top-level sections declare `Type: guide`: one core guide, `scrum-guide-expanded`, and fourteen extension sections. These counts describe source structure, not live publication. Categories and creator pages add non-guide content types. The core guide contains edition `2025.6` and multiple translation files and PDFs.

Eleven languages are configured. Production flags disable tlh, nl, de, ro and it; en and ja have no production disable entry, while fa, pl, es and pt are explicitly enabled. Eligibility must therefore inspect effective configuration, rather than only `disabled: false` lines.

Guide sections such as `adaptive-enterprise` use front matter cascades with `build.list: never` and `build.render: never` for production and preview. Language flags alone cannot explain what should be published. Local templates classify core versus extension by the core slug, render category-filtered extension catalogues and display English-only notices.

The site also has a legacy Azure workflow containing duplicate top-level YAML keys and contradictory warnings/trigger declarations. This is an assessment finding, not a claim that it currently deploys. Inspect its actual GitHub state during migration and resolve it through maintainer review. Preserve unrelated discussion and documentation workflows.

**Fit:** explicit guide roles/relationships, category and creator support, guide/edition/translation-level publication gates, and independently available translations. Klingon is disabled today; making it permanently prohibited is a proposed site policy decision, not an already approved requirement.

### Compatibility matrix

| Capability | KanbanGuides | the-safe-delusion | ScrumGuide-ExpansionPack |
|---|---|---|---|
| Site wrapper ownership | Bespoke, consumer-owned | Bespoke, consumer-owned | Bespoke, consumer-owned |
| Guide collection | Two guide families | One protected guide | Core plus extensions |
| Multilingual wrapper | Required for declared live languages | English only | Partial coverage by language and guide |
| Editions | Several current/historical editions | Preserved 2024.8 edition | Core edition plus extension inventories |
| PDF handling | Generated and supplied inventory | Supplied, protected | Multiple language downloads; provenance needs inventory |
| Editorial pages | Limited | Essential | Categories, creators and introduction |
| Current rendering integration | Primarily configured module templates | Wrapper templates and overrides | Catalogue, creator and markup overrides |
| Publication rules | Language and edition readiness | Protected source and render compatibility | Language plus guide-level cascades |
| Agent scope | Translation and publishing roles | Wrapper-only default | Guide, translation and extension roles |

## 4. Repository and component structure

```text
OpenGuidePlatform/
  system/
    OpenGuidePlatform.Hugo.Guides/
      go.mod
      hugo.yaml
      layouts/
      assets/
      i18n/
      static/
    OpenGuidePlatform.PowerShell.Core/
      OpenGuidePlatform.PowerShell.Core.psd1
      OpenGuidePlatform.PowerShell.Core.psm1
      GuideInventory/
      TranslationReadiness/
      PublicationPolicy/
      EditionManagement/
      ContributorManagement/
      PdfPublishing/
      AgentGovernance/
      Contracts/
      Adapters/
      tests/
    OpenGuidePlatform.PowerShell.Build/
      OpenGuidePlatform.PowerShell.Build.psd1
      OpenGuidePlatform.PowerShell.Build.psm1
      Prepare/
      Build/
      Validate/
      Verify/
      Reporting/
      Adapters/
      tests/
    OpenGuidePlatform.AgentSkills/
      guide.transcreate/
      guide.transreconcile/
      guide.transstatus/
      guide.genpdfs/
      guide.historicalversion/
      guide.contributions/
      guide.gravatar/
    OpenGuidePlatform.AgentControls/
      codex/
      claude/
      copilot/
      managed/
  templates/guide-site/
  examples/reference-guide-site/
  tests/consumer-contracts/
  .github/workflows/
  .build/
  build.ps1
  docs/architecture/
```

Component names identify distributable units. Capability directories identify reasons for change. `Core` is restricted to guide-publishing operations and contracts; it is not a general-purpose utility collection. Its schemas live under `Contracts/` and are packaged for consumers rather than maintained in duplicate. `Hugo.Guides` supplies guide rendering and presentation data to bespoke wrappers; it is not the owner of their site design.

`PowerShell.Build` depends on Core. Core's policy and readiness functions accept data and return structured results without GitHub environment variables, workflow output, network calls or Hugo execution. Filesystem, Pandoc, Hugo and external integrations enter through adapters. Pure decisions and side-effecting use cases have separate tests.

The root platform `build.ps1` builds and tests OpenGuidePlatform. The consumer bootstrap imports the released Build module to build a guide site. These are different roles even though they share the familiar command name.

Architecture checks enforce dependency direction, prohibit GitHub-specific references in domain functions, and require explicit contracts for capability interactions. Avoid empty interface hierarchies added only to resemble a diagram.

## 5. Hugo architecture and extension compatibility

**Sequencing constraint:** do the internal module refactoring in this section last (execution plan E14). First relocate the module mechanically with only essential path/identity changes, build the other platform components and verify their integration with all three sites in isolated builds and previews. Preserve current functionality, visual output and the deliberately non-standard multilingual guide structure. Do not normalise it to conventional Hugo patterns.

During adoption, Hugo keeps its current rendering inputs, partials, availability logic and wrapper integration. Prepare and artifact validation operate around that existing behaviour; the proposed publication manifest is not yet a rendering dependency. E05 establishes regression coverage, not a refactor.

Once the other work builds and is verified across the sites, return to the module refactoring below. Check every guide against the working pre-refactor builds to preserve multilingual behaviour, functionality and visual output before confirming the changes. This does not require prior stable releases, production deployment or operational handover.

Retain Hugo's conventional component directories. Inside `_partials/openguide/`, organise by `guides`, `editions`, `translations`, `downloads`, `attribution`, `discovery` and `adapters/hugo`. Organise assets under matching capability names. Entry templates such as `guide/history.html` delegate to an inventory adapter and a presenter. The bespoke consumer wrapper composes these guide capabilities into its own shell.

The site homepage, overall navigation, header/footer, brand styling, editorial layouts and collection presentation belong to each consumer. Do not make `site-shell` a compulsory part of `Hugo.Guides`. Consumer-owned composition can continue using supported shared presentation components; it does not require duplicating them into each site. Preserve existing module-provided wrapper templates during adoption and evolve their integration only in E14 with verified compatibility. An optional starter wrapper may live in `templates/` and become site-owned when adopted. It must not be overwritten by routine platform updates. A separately installable wrapper module would require a demonstrated consumer need, not be presumed necessary.

The current `functions/` versus `components/` split scatters edition and translation behaviour. `render-guide.html` combines availability decisions, downloads, UI and script; it also uses a content-length threshold to determine availability. Refactor these responsibilities around an explicit edition/translation view model.

Do not rebuild the policy engine in Go templates. Core defines publication state; the build emits a versioned, internal publication manifest for Hugo to consume. Hugo may still discover pages/resources for presentation, but must not silently derive a contradictory eligibility decision. Missing or incompatible manifest data is a validation failure in the supported build path. Internal assessment details and contributor policy must not be copied into public output.

Keep raw Hugo invocation available for diagnosis, but define `build.ps1` as the supported route for publication. The manifest is generated outside tracked content and mounted into the build. Map it into a stable presentation contract rather than expose CI report structure directly to templates.

Move demo domains, analytics identifiers and environment-specific deployment values out of the reusable module into the reference site or consumer configuration.

Define stable integration contracts through which each bespoke wrapper consumes guide/edition catalogues, translation availability, download links, attribution and rendering primitives. Wrapper-owned homepage and navigation code are first-class composition, not exceptions to platform ownership. Inventory consumers' overrides against their pinned module before upgrading. Existing overrides either receive a documented migration or remain temporarily supported behind a compatibility adapter. Preserve public URLs, aliases, heading anchors and PDF paths unless an explicit migration provides redirects.

The current three sites support one cohesive Hugo module. Add another module only when independent adoption is demonstrated; examples might be a separately useful presentation theme or search integration. No additional Hugo module is required to complete this first adoption.

## 6. Publication contracts and site policy

Model Site, Wrapper, Guide, Edition, Translation, Download, Contributor and PublicationTarget explicitly. Each Site has a bespoke Wrapper and one or more Guides. Guide roles such as core/extension are declared relationships, not magic slug comparisons. Non-guide content types remain supported and do not receive guide-specific schema requirements.

Wrapper readiness uses a site-declared manifest of required routes, language resources, assets and integration points. It must not assume every site has KanbanGuides' seven structural files or the same navigation. The platform validates those declarations using common mechanisms. Consumer-specific checks run through an explicit extension port and remain distinct from mandatory platform gates; they cannot replace or suppress trusted publication policy.

Readiness is not one boolean. Record wrapper coverage, body state, review state, download availability and publication eligibility separately. Useful presentation states include `web`, `pdf-only`, `english-fallback`, `scaffolded`, `missing`, `not-applicable`, `excluded` and `prohibited`.

Presence does not establish translation quality. Language codes should follow the actual supported language-tag contract, including numeric regions such as es-419; the current skill's casing rule is too narrow. Do not reorder languages through web searches during builds.

The build assesses the source inventory against site policy and then verifies the effective Hugo configuration and artifact. This includes front matter cascades, drafts, render/list flags and environment overrides. During migration, differences between policy and Hugo behavior fail with an explanation; never silently rewrite publication flags to make them agree. Reports show Wrapper readiness separately from readiness of each Guide and Edition, whether the inventory contains one guide or many.

Example consumer configuration (proposed schema, not executable today):

```yaml
schemaVersion: 1
site:
  id: kanban-guides
  source: site
  sourceLanguage: en
publication:
  production:
    allowedLanguages: [en, es-ES, fr, ja, fa]
    prohibitedLanguages: [min]
authoring:
  allowAgentWrapperTranslation: true
  allowAgentGuideBodyTranslation: false
guides:
  the-kanban-guide:
    editions: version-directories
    historicalTranslationFallback: english
    pdfFilename: 'kanban-guide.v{edition}.{language}.pdf'
  open-guide-to-kanban:
    editions: version-directories
    pdfFilename: 'open-guide-to-kanban.{language}.pdf'
```

For safe-delusion, add protected source/download paths and an approved rendering-compatibility baseline. For Scrum, declare core/extension relationships and explicitly map guide publication restrictions. Optional capabilities are assessed only when selected; mandatory production policy is never optional.

Temporary accepted findings must identify the exact rule and subject, reason, owner and expiry. Stable publication choices such as PDF-only are first-class policy, not temporary exceptions. Do not provide an exception for KanbanGuides' Minionese prohibition.

## 7. Build contract and GitHub workflows

Proposed commands:

```powershell
./build.ps1                         # Prepare, Build, Validate locally; no deployment
./build.ps1 prepare
./build.ps1 build -Ring production
./build.ps1 validate -Ring production
./build.ps1 verify -BaseUrl https://example.test -ExpectedCommit <sha>
./build.ps1 -Versions
```

The default includes local configuration verification and production-policy validation. CI validates the actual deployment artifact plus production output where the PR target differs. Output paths are ring-specific, fresh and confined to an explicit output root. Generation does not modify tracked inputs. Reject unsafe output paths and path traversal during package extraction.

Stages: **Prepare -> Build -> Validate -> Deploy -> Verify**. Prepare evaluates all independent checks, writes JSON/Markdown and then fails for blocking findings. Dependent checks record blocked/unknown if prerequisites fail. Missing reports, validator crashes and skipped mandatory checks never count as success.

Build owns generated overlays, Hugo execution, native command exit checks, asset packaging and the final merged Static Web Apps configuration inside the deployment artifact. Validate checks routes, links, indexes, downloads, unresolved tokens, size and publication exclusions. Deploy consumes the validated artifact without rebuilding. Verify checks the deployment identity and behavior.

OpenGuidePlatform provides reusable `guide-site.yaml`, cleanup and update workflows. Consumers retain thin callers with triggers, minimum permissions and explicit secret mappings. The shared workflow provisions tools, invokes PowerShell, moves artifacts and calls the deployment action. It does not contain another copy of domain validation logic. Site-specific discussion/wiki workflows remain local.

Proposed ring mapping: PR -> canary, main -> preview, stable site-release tag -> production. Make merge_group validation-only. Manual runs must resolve an authorised target explicitly. Test this against each site's current GitVersion and trigger behavior before switching. Platform prerelease status is independent of site deployment ring.

Use the final stage names immediately and update required checks with the migration. A trusted aggregate required check can enforce mandatory stages even when optional deployment is skipped, particularly for fork PRs without preview credentials. No unavailable fork deployment should leave an impossible required status pending.

## 8. Validation rules

| Rule family | Enforcement |
|---|---|
| Production eligibility | Fail on forbidden language, undeclared enablement, excluded guide/edition exposure, or configuration/artifact disagreement. |
| Source/schema | Fail invalid YAML/JSON, duplicate keys, forbidden `lang:` front matter, invalid references and missing required metadata. |
| Translation readiness | Fail missing requirements for declared publication mode; report disabled scaffolds without treating them as live failures. |
| Routes/downloads | Fail broken internal routes/anchors, duplicate destinations, redirect loops and missing referenced PDFs. |
| Protected content | Fail unauthorised protected-source edits or regeneration; require review for rendering/dependency changes affecting protected guides. |
| Agent governance | Fail instruction drift, missing required adapters and unreviewed changes to enforcement sources. |
| Build artifacts | Fail unresolved tokens, wrong target configuration, size limit breach, malformed required JSON and stale/mismatched build identity. |
| Dependencies | Warn when a newer stable platform/Hugo module is available; report unavailable lookup as unknown. Fail missing required tools or unsupported versions needed for the requested operation. |
| Review authority | Require appropriate technical/editorial review; automation does not certify wording accuracy, translation quality or licence compliance. |

HugoGuides freshness currently needs the module's subdirectory tags, not the latest repository release alone. After adoption, the platform manifest supplies the tested Hugo version. The updater resolves newer compatible releases; normal builds use the lock. No implicit upgrades and no production module `replace` pointing to a developer's neighbouring checkout.

Offline builds with a populated cache may pass deterministic checks while reporting freshness as unknown. A missing required package still fails with a clear restore instruction. Network checks should have bounded timeouts and never mutate source.

## 9. Distributed skills and PDF operations

Retain the seven familiar `guide.*` skill names initially. Move deterministic scripts into Core capabilities, with skills invoking supported commands. Transstatus uses the same inventory/readiness engine as Prepare; transreconcile repairs scaffolding without overwriting real translations or enabling production by default. Wrapper scaffolding and translation use the consumer's declared wrapper inventory and approved templates, not a universal homepage or fixed Kanban file list. Wrapper translation and guide translation are independently assessed operations.

Correct the current skills before release: hard-coded guide names/editions, Minionese tone guidance, conflicting `lang:` rules, historical path assumptions, populated-body warnings and implicit production enablement. Site policy decides whether agent translation of guide bodies is permitted. Wrapper translation is an agent task; scaffolding, preservation and validation are deterministic operations.

Edition creation selects its strategy from the declared content layout. It must refuse a conflicting existing edition by default, preserve all resources and translations, and never apply the old latest-to-history algorithm blindly to version-directory sites.

PDF publishing supports Pandoc/XeLaTeX, explicit guide/edition/language selection, template overrides, font diagnostics and RTL/CJK fixtures. Distinguish generated from supplied/protected PDFs. Freshness fingerprints include source, template, assets, configuration and relevant tool versions. Avoid claiming byte-for-byte determinism until timestamps and PDF metadata are controlled.

Check PDF validity and page presence automatically, plus representative visual output for layout-sensitive changes. Do not rebuild all historic or externally supplied PDFs in an ordinary site build. The build validates declared downloads; generation is an explicit supported operation. Missing TeX only blocks operations that require it.

Skill definitions and supporting references ship with the tooling release. Agent-specific installers place them in tested discovery locations without creating competing maintained copies. Site extensions live separately. Installer/update conflicts are reported as diffs, never overwritten silently.

## 10. Agent protection and trust boundaries

One canonical site instruction document under `.agents/` supplies identical root `AGENTS.md` and `CLAUDE.md` entry points plus a Copilot adapter. Prefer generated full entry documents when they remain compact; otherwise include critical rules in the identical bootstraps and explicitly reference the canonical document. Validate consistency and referenced files.

Core holds portable governance checks. AgentControls adapts them to Codex, Claude and Copilot. Support is a tested matrix of client, version, OS and execution surface; a syntactically valid file alone is insufficient proof that the client enforces it.

| Layer | Purpose | Limit |
|---|---|---|
| Instructions/skills | Explain permitted work and repair actions | Model guidance, not an access boundary |
| Project hooks/settings | Immediate feedback and accidental-change prevention | Editable project state and varying tool coverage |
| Administrator policy / isolated workspace | Restrict file writes, credentials, network and available profiles | Requires managed deployment; local administrators remain authoritative |
| Trusted GitHub checks and review | Enforce what can merge | Must be protected from candidate-controlled replacement |
| Trusted deployment | Enforce what can publish | Must not execute candidate scripts with deployment credentials |

Codex supports managed requirements and permission profiles; newer profile controls require compatible versions. Claude supports managed permissions, bypass restrictions and managed hooks. Copilot CLI and cloud support hooks, but machine-wide CLI policy does not transfer to cloud jobs; IDE capabilities differ. Hook timeouts and uncovered tool paths mean hooks are supplemental controls.

Provide contributor and maintainer profiles. Contributors can edit allowed content and run trusted build tooling; protected policy, workflows, dependencies and audited content are read-only. Maintainer access is granted outside repository-controlled settings, not by a label or instruction file. Protect shell and MCP paths too: an edit-tool deny rule does not restrict an unrestricted shell.

The default local build may execute changed build code for development. The mandatory trusted gate must load its evaluator and policy baseline from an approved source, and treat candidate content as data. Changes to policy or evaluator require technical review before adoption. An ordinary reusable-workflow caller is not sufficient if the PR can remove or repoint it; back it with ruleset-required trusted execution where supported or a separate protected check producer. Evaluate available GitHub plan capabilities during implementation.

Never run untrusted PR scripts in a privileged reporting workflow. Keep deployment credentials in trusted deployment jobs. Protect package pins, workflows, policy, instructions, hooks and module tags with owner review and controlled credentials. A checksum validates downloaded bytes against a trusted expectation; a checksum supplied solely by a malicious candidate is not independent trust.

## 11. Reporting and mockups

One report contract generates console output, Actions summaries, file annotations and an updated PR comment. Findings carry rule ID, severity, subject, source path/line, observed/expected state, reason, repair guidance and verification command. Include commit, policy/platform versions, target, time and run URL.

Keep one bot-owned comment; prevent older runs overwriting newer results. Report blocked and skipped stages honestly. Public comments omit secrets, local machine details and unnecessary personal data. Validate and escape untrusted report text before publishing. Always upload reports when possible, including failed Prepare runs.

**Illustrative Actions failure, not a current scan:**

```text
OpenGuidePlatform / KanbanGuides                 PREPARE FAILED
Commit abc1234 | Platform 1.4.0 | Target canary
Production policy assessed: yes

PASS  Source schemas
FAIL  Production eligibility                    PROD001
FAIL  Required French interface strings         I18N002
PASS  Protected changes
WARN  Platform update available

Build      BLOCKED
Validate   NOT RUN
Deploy     NOT RUN
Verify     NOT RUN

Fix 2 errors, then run ./build.ps1 prepare
Artifacts: analysis.json | analysis.md | language-inventory.json
```

**Illustrative language panel:**

| Language | Production | Wrapper | Current web editions | Historical editions | Downloads |
|---|---|---|---|---|---|
| English | Eligible | Complete | Present | Present | Verified |
| French | Blocked | One required key missing | Present | Permitted English fallback | Verified |
| Polish | Disabled | Complete | Present | Incomplete | Reported |
| Minionese | Prohibited | Present | Present | Present | Excluded |

Scrum's panel additionally expands by guide and target: an unpublished extension reports `Excluded by guide policy`, not `Missing translation`. Safe-delusion reports the audited guide as `Protected; unchanged` and separately reports wrapper link/anchor checks.

**Illustrative PR comment:**

> **Changes required: 2 errors, 1 warning**
>
> Analysed commit `abc1234`. Build and deployment are blocked.
>
> **PROD001: Minionese is not eligible for production.**
> In `site/hugo.production.yaml`, restore `languages.min.disabled: true`.
> Changing the canary target does not bypass production-policy validation.
>
> **I18N002: French is missing a required interface key.**
> Add the reported key to `site/i18n/fr.yaml` using the English entry as reference.
>
> **Warning:** a newer stable platform release exists. The pinned release was used.
>
> Verify: `./build.ps1 prepare`, then `./build.ps1`.
>
> Full analysis | Language and guide inventory | Workflow run

**Illustrative successful deployment report:**

```text
Prepare PASS | Build PASS | Validate PASS | Deploy PASS | Verify PASS
Deployed commit: abc1234 (matches expected)
Platform: 1.4.0 | Target: preview
Required routes, guide downloads and internal anchors verified
Intentional fallbacks: 4 | Advisory warnings: 1
Preview URL | Full report
```

## 12. Post-deployment verification

Verify the exact deployment commit, expected ring and platform version before accepting HTTP success. Check page identity and content type so an error/fallback page cannot pass merely by returning 200. Retry within bounded propagation limits.

Common checks cover homepage, declared guide/edition routes, language selection, sitemap and JSON outputs when enabled, representative downloads, redirects and browser navigation. Production checks include prohibited-language absence. Canary can intentionally expose reference languages; apply the right policy.

Consumer-specific checks: Kanban language and edition links; safe-delusion wrapper-to-audited-guide anchors and preserved PDF; Scrum core/extension categories and absence of cascade-excluded guides. External links can be advisory or checked separately to avoid unrelated network outages blocking every content PR.

A failed preview verification blocks the appropriate merge gate. Failed production verification fails the deployment outcome and gives a recovery action. Keep the known-good artifact and provenance for rollback; do not add automatic rollback until the recovery path is tested.

## 13. Releases, distribution and updates

Use public GitHub Releases as the release catalogue. PR builds produce temporary artifacts; preview versions such as `v1.4.0-preview.3` are prereleases; stable versions such as `v1.4.0` are normal releases. These are platform channels, independent of site canary/preview/production targets. Production sites default to stable platform releases.

Each coordinated release binds:

- `release-manifest.json`: exact source/workflow commit, component versions, schema versions and minimum toolchain requirements.
- `OpenGuidePlatform.Tooling.zip`: Core, Build, AgentSkills, AgentControls and consumer templates.
- Checksums and provenance/attestation where supported.
- Compatibility report and migration notes.
- A native Hugo module tag at the matching source revision.

For the selected layout, the initial pre-v2 import path is `github.com/<owner>/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides` and the corresponding subdirectory tag is `system/OpenGuidePlatform.Hugo.Guides/v1.4.0`. Confirm the owning organisation before publishing. Major-version Go module path requirements must be handled explicitly if/when v2 is introduced.

Upload complete release assets before publication; enable immutable releases. Preview and stable labels are discovery aids, not moving build inputs. A stable release is validated from the selected source; do not assume version-stamped preview and stable package bytes are identical. Rebuild/retest where metadata changes require it.

Consumers commit `guide-platform.yaml`, `guide-platform.lock.json`, a small `build.ps1` bootstrap, native Hugo `go.mod`/`go.sum` and generated adapters. Their bespoke wrapper templates, styling, navigation and editorial content remain consumer-owned files. Clearly separate generated platform entry points from adopted starter files: only the former are regenerated by updates. Restore tooling into a versioned ignored cache, verify it, import by exact path and preserve offline reuse. Do not require machine-global module installation or PowerShell Gallery for v1.

GitHub reusable workflows are referenced directly by commit SHA. The caller reference cannot be dynamically loaded from a lock file; the updater changes both and validates their consistency. A default checkout in a reusable workflow is the consumer: platform tooling must be restored explicitly from the pinned release, not assumed present in the checkout.

The updater resolves an explicitly requested version or channel once, updates all pins/generated files, runs the full build and creates a reviewable diff. Cross-repository update PRs require a narrowly scoped GitHub App or equivalent identity. Routine builds only warn about newer versions. Remote publication and messaging are explicit updater operations, not side effects of `build.ps1`.

Project agent adapters are distributed through the release. Administrator policy templates require a distinct installation process and protected executable location. CI can verify repository integration, not every developer's effective workstation controls.

Rename migration must update Hugo imports, module declarations/tags, workflow callers and documentation explicitly. GitHub does not redirect reusable workflow references after a repository rename. Preserve historical release availability and test legacy module resolution; use an intentional transition release/compatibility repository if required rather than promise redirects will preserve everything.

## 14. Migration plan and acceptance criteria

### A. Establish contracts and baseline fixtures

Capture each consumer's routes, downloads, configured languages, publication exclusions, relevant template overrides and source revision. Read their authoritative contribution policies. Resolve the safe-delusion instruction/override discrepancy and inventory Scrum's legacy deployment workflow before changing execution paths.

Acceptance: fixtures reproduce multilingual editions, PDF-only delivery, English fallback, protected supplied content, core/extension categories and guide-level exclusions. Each fixture declares expected output rather than duplicating current implementation logic.

### B. Create the named platform components

Extract publishing/build implementation, add explicit Core contracts and Build stages, and preserve existing Hugo internals and wrapper integration. Limit module changes to mechanical relocation and essential identity/path updates; E05 adds cross-consumer regression evidence. Generalise and correct all seven skills. Introduce the reference site and tests before relocating the public module import path.

Acceptance: Core policy tests are independent of Hugo/GitHub; both local and CI use the same stage implementation; reports are written on failure; package restore verifies identity; agent adapters pass client/version compatibility tests.

### C. Pilot KanbanGuides

Adopt pinned tooling and shared workflow callers. Replace token substitution with generated overlays, place final hosting config inside the artifact, and make size/native-command failures real failures. Enforce Minionese prohibition through trusted policy and artifact checks. Repair instructions and CODEOWNERS through review.

Acceptance: local and production builds pass; a fixture enabling Minionese fails; no forbidden routes/downloads leak; translation inventory correctly distinguishes fallback; update PR is reviewable and rollback works. Update GitHub required checks to the final stage names.

### D. Validate the two other consumer shapes

Adopt safe-delusion preserving the guide/PDF bytes, guide rendering contract and wrapper source links. Adopt Scrum preserving category/creator pages, core/extension presentation, translations and per-guide exclusion behavior. Changes to outdated configuration occur in explicit migration diffs.

Acceptance: all declared consumer contracts pass; approved overrides remain effective; no protected content changes; no previously excluded publication becomes exposed. Permanent Klingon prohibition requires a separate consumer policy decision.

### E. Release and govern updates

Publish preview, open tested consumer update PRs, then publish stable after compatibility evidence. Install managed contributor policies separately. Protect platform releases, required execution and production credentials.

Acceptance: pinned builds are repeatable; a newer release cannot silently change an old build; failed reporting cannot fabricate success; an agent cannot weaken project checks and thereby pass the independent trusted gate.

### F. Refactor Hugo module contents last

Keep the module refactoring described in section 5, but do it after the rest of the platform has been built and verified against the three guide sites. This is an ordering constraint, not a new hardening programme. Stable release, production adoption and handover are not prerequisites.

Acceptance: compare the refactored module against the working pre-refactor builds across all guides in all three sites. Preserve functionality, the deliberate multilingual structure and visual output before confirming the changes.

## 15. Decisions for review

The recommended defaults are named `system/` components, one coordinated release, one Hugo module, Core plus Build PowerShell modules, shared workflows and versioned skills. No extra platform service or private package registry is required initially.

Before implementation, settle:

1. Owning GitHub organisation and the rename/compatibility strategy for existing Hugo module users.
2. Approvers for platform policy, consumer publication policy and audited guide rendering changes.
3. Which agents/versions/OSes are mandatory for the first managed-policy rollout; include Copilot CLI, cloud and IDE as distinct surfaces.
4. Explicit treatment of existing historical fallbacks and supplied/generated PDF provenance.
5. Whether Scrum's Klingon reference language is permanently prohibited or simply currently disabled.
6. GitHub plan capabilities for externally enforced workflows/checks and immutable releases.

These decisions do not prevent starting contract tests and component extraction, but they affect production rollout and security claims.

## 16. Sources and implementation references

Repository evidence paths are relative to each named repository and refer to the assessed working trees:

- KanbanGuides: `site/go.mod`, `site/hugo*.yaml`, `site/content/`, `.agents/skills/`, `.github/workflows/main.yaml`, `.github/CODEOWNERS`, `docs/README.md`.
- the-safe-delusion: `AGENTS.md` (untracked), `site/hugo*.yaml`, `site/layouts/`, `site/content/safe-decision-makers/`, `.github/workflows/main.yaml`.
- ScrumGuide-ExpansionPack: `site/hugo*.yaml`, `site/content/adaptive-enterprise/_index.md`, `site/content/scrum-guide-expanded/`, `site/layouts/_partials/functions/is-expansion.html`, catalogue templates and `.github/workflows/`.
- HugoGuides: `module/`, `AGENTS.md`, `.github/instructions/module.instructions.md` (PDF-only and independent translation support).
- NKDAContent-Hub: `build.ps1`, `.github/workflows/channel-build.yml`, `system/NKDAgility.PowerShell.HubBuild/Public/Invoke-HubBuildPrepare.ps1` and `Invoke-HubBuildRelease.ps1`.

Official documentation supporting the design:

- [Hugo modules and native dependency management](https://gohugo.io/hugo-modules/use-modules/).
- [Hugo component mounts and precedence](https://gohugo.io/configuration/module/).
- [Go module repository layout and subdirectory version tags](https://go.dev/ref/mod#vcs-version).
- [Reusable GitHub workflows and immutable SHA references](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).
- [Reusable workflow limitations, including repository renames](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations).
- [GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).
- [Codex managed configuration](https://learn.chatgpt.com/docs/enterprise/managed-configuration) and [hooks](https://learn.chatgpt.com/docs/hooks).
- [Claude Code administrative controls](https://code.claude.com/docs/en/admin-setup).
- [Copilot hook capabilities and limitations](https://docs.github.com/en/copilot/reference/hooks-reference).

Provider controls evolve. Pin and test supported client versions during implementation; this proposal does not claim that managed controls are installed on the contributors' devices today.
