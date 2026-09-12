# ADR 001 — Coordinated platform releases

Status: implementation decision for E01; publication remains gated by E07/E08.

Hugo modules use Go module tags, workflows use Git commit identities, and PowerShell/skills/controls use package assets. Independent updates can produce an untested combination.

Publish one coordinated release manifest/lock containing each exact identity, source commit, package digest and toolchain. Preview and stable are release channels, not mutable version aliases. Existing tags remain unchanged. Use release-specific caches and atomically propose a lock, Hugo pin, workflow SHA and generated-adapter update together.

This gives each consumer a reviewable update unit while retaining native distribution mechanisms. Packaging, clean-cache resolution and source/digest coherence are acceptance tests in E07; a structurally valid lock is not enough.
