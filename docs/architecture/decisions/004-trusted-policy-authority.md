# ADR 004 — Policy authority is outside the candidate

Status: implementation boundary; deployment mechanism and owner groups must be verified in E06 before rollout.

AGENTS.md, CLAUDE.md, Copilot instructions, repository-local hooks, schemas and tests can all be edited in a PR. They are useful guidance but cannot be the authority that approves that PR.

Evaluate mandatory publication and protected-edit policy from a maintainer-controlled source that the candidate cannot replace. Treat candidate files as untrusted data. Run candidate build scripts without privileged credentials; privileged reporting and deployment must not execute them. Bind results to repository, source commit, evaluator identity and policy digest.

Repository administrators own the external enforcement configuration; consumer maintainers own reviewed publication requirements, while platform maintainers own released evaluator code. No fixture, PR label or candidate role field grants those permissions. Exact team/App identities and the available GitHub enforcement mechanism must be established and tested in E06; the current ADMIN access and rulesets do not prove an independent gate is already available.

Acceptance requires tamper tests against deleted/modified local checks, fork behavior without secrets, and a required result from the trusted evaluator. Client-side managed settings remain a separate administrator installation. Do not describe generated templates as installed controls.
