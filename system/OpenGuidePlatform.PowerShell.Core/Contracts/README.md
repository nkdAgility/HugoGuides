# Platform contracts — version 1 candidate

These contracts belong to Core because they describe publishing intent and observations. They do not introduce new Hugo rendering inputs. Build, GitHub reporting, filesystem discovery, PDF generation and agent integrations adapt to these contracts.

| Contract | Responsibility |
|---|---|
| site-policy.schema.json | Bespoke wrapper requirements, guide/edition structure, translation intent, download handling and environment exclusions |
| assessment.schema.json | Observed wrapper/guide readiness, findings, evidence, remediation and stage outcome |
| platform-lock.schema.json | Exact coordinated package, module, workflow, component and toolchain identities |

The version-1 JSON Schemas are draft-07 and self-contained. Unknown fields and unsupported schema versions fail validation. A future incompatible contract gets a new schemaVersion and an explicit migration; tools must never silently reinterpret it. Version 1 is a candidate until E03/E04 operations and E07 distribution exercise it end to end.

`tests/Contracts/fixtures` contains representative shapes, not installable consumer policies. The one-, two- and fifteen-guide examples use discovered guide names and editions, but their wrapper requirements and translation selections are deliberately incomplete. They must not be injected into deployed sites. The lock has synthetic hashes and an example.invalid package URL, not a release reservation.

Run `pwsh -File .build/Test-PlatformContracts.ps1` locally. The thin Platform contracts workflow runs the same assertions without secrets. E04 incorporates this check into the root build entry point.

## Meaning and ownership

- Consumers own their wrapper requirements and content. There is no universal wrapper file list.
- `intent` declares web, PDF-only, fallback, scaffold or excluded publication. The separate observed state may be unknown. A populated file is not evidence of a reviewed translation.
- Paths in site policy are repository-relative except edition.path (relative to guide.contentRoot) and download.path (relative to its edition). All use forward slashes. Future adapters must resolve and verify containment, including links/reparse points; lexical schema checks are insufficient.
- Permanent exclusions are checked against production configuration even when the requested build targets preview. Kanban's Minionese prohibition is a permanent rule; Scrum's current Klingon exclusion is environment configuration, not an invented permanent prohibition.
- Protected paths and supplied/protected downloads are preservation constraints. Build cannot infer permission to regenerate or edit them.
- A candidate JSON file cannot grant maintainer authority. Trusted policy ownership and reviewer decisions live outside candidate-controlled input. Unknown authority fails closed at the enforcement adapter.
- Findings carry a stable code, affected scope/subject, explanation, remediation and evidence. A pass with a blocker is structurally invalid. Missing/dependent checks yield blocked, not pass.
- Source-language fallback and extension relationships name their targets explicitly. Schema validation checks shape; it cannot establish whether those targets exist.

## Semantic validation still to implement

E03 validates unique guide/edition/language keys, extension and fallback references/cycles, intent/download consistency, actual filesystem containment, protected hashes and effective publication rules. E04 computes report outcomes from checks and diagnoses missing reports; a caller-supplied outcome is not trusted. E07 validates package digests, module tag/source provenance, workflow/source coherence and supported toolchain combinations. E06 evaluates authoritative policy independently of PR-modifiable tests and schemas.

Passing these structural tests is not evidence that those enforcement features already exist. No schema or fixture is loaded by Hugo or by a consumer build at this stage.
