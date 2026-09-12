# ADR 003 — Immutable shared workflow identity

Status: implementation decision for E01; workflow distribution is E07.

Consumers need thin GitHub Actions callers, while the same build operations must run locally. A mutable workflow branch would undermine the release lock and make recovery ambiguous.

Consumer workflows declare triggers, minimal permissions, explicit secret mappings and a reusable workflow pinned to its tested commit. The release lock records that commit. Shared jobs provision tools, invoke PowerShell stages and transport/deploy validated artifacts; they do not duplicate publication policy.

Prepare, Build, Validate, Deploy and Verify are the final check names. Existing names are not architectural constraints. Check registration and rules change together at adoption, with required enforcement maintained. Because GitHub does not redirect renamed workflow callers, E08 explicitly updates known callers and rechecks external consumers.
