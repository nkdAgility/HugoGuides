# ADR 003 — Versioned shared workflows and source provenance

Status: reconciled with the maintainer's explicit version-tag instruction. Supersedes the earlier requirement to put a commit SHA in a workflow `uses` reference.

Consumer workflows use version tags, never commit SHAs. Use the broadest supported version label unless the coordinated preview being evaluated requires its release tag. Third-party actions use their supported major version labels unless compatibility requires a narrower version. A source SHA is provenance, not an action reference.

The coordinated lock records `workflow.version` (the version tag used in `uses`) separately from `workflow.commit` (the source evaluated with the package). Distribution verifies the resolved source and supported combination; it must not silently equate a moving version label with immutable bytes. Preview adoption currently uses its release tag because it evaluates that particular package combination. Supported broader platform labels and update handling are E07/E13 work; they are not prohibited by this contract.

Consumers keep triggers, permissions, inputs and secret mappings. The shared workflow provisions tools and invokes the common build stages. Prepare, Build, Validate, Deploy and Verify remain the check names. Rules are changed deliberately during adoption; old check names are not a compatibility requirement.

Platform main.yaml directly calls the same shared workflow for the sample using its newly built ZIP URL and expected identity. Publication waits for sample success and reuses the same artifact. There is no separate sample-main workflow or publication polling dependency.