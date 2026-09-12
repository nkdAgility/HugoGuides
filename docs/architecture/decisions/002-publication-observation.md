# ADR 002 — Observe publication without changing Hugo inputs

Status: adopted for the migration implementation.

The existing guide/edition/language structure is deliberate and fragile. Replacing it with a manifest during adoption would mix infrastructure migration with rendering behavior changes.

Core records declared publication intent and observed states. Build validates effective configuration and rendered artifacts. Hugo continues to consume its existing content, front matter, configuration and module inputs. No readiness report becomes a rendering input during adoption.

The proposed publication manifest and internal module refactoring remain E14, after the other platform work builds and is verified across all three consumers. This preserves the work and its original scope without making it a prerequisite for relocation.
