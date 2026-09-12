---
name: guide.contributions
description: "Create guide contributor YAML from supplied contributor records and preserve existing files."
---

Read [Core usage](../USAGE.md), load the consumer policy, and select the declared guide. Use `New-GuideContributions -WorkspaceRoot $WorkspaceRoot -Policy $policy -GuideId $GuideId -Contributors $Contributors` for a new file.

Records need a name and role (creator, contributor or involved). Preserve supplied URLs, edition references and other contributor metadata; do not invent affiliations or contributions. Use `Get-GuideGravatar` only for an address the user supplied for that purpose.

The command refuses replacement of an existing contributor file. For an update request, inspect and describe the required minimal diff; existing-file mutation support is not part of this initial extracted command. Do not use Force or overwrite the file to bypass the refusal. Report the created path and run the consumer build after any authorized change.
