# First-time guide-site setup

This page is for the maintainer adopting OpenGuidePlatform into an existing guide site. Contributors to an already adopted site can use the [README commands](../../readme.md#everyday-use).

Adoption is currently a preview migration. Keep it on a branch and verify the site's existing content, design, routes and downloads before accepting it. The installer does not create a new website or rewrite the guide structure.

## Use the existing Hugo source

No site policy file is required. The default source is `site/`; supply `-SourcePath` for another Hugo directory. Keep language enablement in Hugo YAML and content metadata in the existing bundles.

Prepare discovers guide roots, editions, translation bodies, PDF resources and Hugo public URLs. It checks the root, history and translations scaffolding for active guide languages. The resulting inventory is build evidence under `.processing/`, not a second set of content declarations to maintain.

Keep destination settings in the `delivery` mapping of `.OpenGuidePlatform/settings.yaml`. Upgrade migrates the old delivery file and source path transactionally; `installation.json` remains generated JSON. Installation writes its record and resolver under `.OpenGuidePlatform/`; the thin root `build.ps1` remains the command people run.

## Install and integrate

Preserve existing edits and create a review branch, then run the install command in the [README](../../readme.md#install-or-update).

The installer refuses conflicting existing files, including build scripts, workflow callers and agent instructions. Review each conflict and migrate the existing behaviour deliberately before retrying. Do not remove bespoke instructions, workflows or content merely to make installation succeed.

The wrapper must already have a `site/go.mod` (or the equivalent under its configured source folder) and its Hugo module import in YAML. The installer updates the native module identity, version and checksums together with the platform. Unsupported YAML forms or locally modified managed files stop installation for review; the installer does not reformat the whole configuration. Local-only module replacement destinations are preserved.

Review the resulting module/configuration diff, build adapter, installation record, skills and instructions. Build preview and production output. Check guide bodies, language fallbacks, links, downloads and the site's appearance against the existing site.

The starter triggers the same pipeline for pushes to `main`, pull requests and version-tag pushes (for example `v1.2.3` or `1.2.3`). Prepare uses GitVersion to select the site version and ring; the installed OGP pin remains unchanged. Existing sites own their callers and must add the tag triggers themselves. Tag a commit that already contains the updated workflow; adding the trigger does not replay older tag pushes.

The installer creates a small site-owned caller when no OGP caller exists. It starts with deployment disabled. Configure its triggers, concurrency, inputs and secret mapping for your site; keep build logic in the shared workflow. Add the [shared close-PR workflow](../../.github/workflows/guide-site-close-pr.yaml) through another site-owned caller. The platform's [sample cleanup caller](../../.github/workflows/sample-close-pr.yaml) illustrates this; its hosting destination and secret belong to the sample, not your site.

### Caller ownership and updates

PR cleanup must use the same environment name as deployment. The shared cleanup
workflow defaults to the PR number, preserving existing callers. If your delivery
configuration uses `environment: canary-{pr}`, add this job input to your site-owned
cleanup caller:

```yaml
with:
  deployment-environment: canary-${{ github.event.pull_request.number }}
```

Pass the resolved name, not the `{pr}` template. Cleanup accepts the name directly;
it does not read the site's delivery file. Keep the caller on the pull request
`closed` event. Confirm the deployment and cleanup names match before enabling
deployment.

Existing language-prefixed legacy download aliases are preserved during discovery.
For example, Hugo can render a Polish `/pl/downloads/` alias at
`pl/pl/downloads/index.html`. Validation accepts that existing path without
rewriting the source alias; duplicate exemptions still require the exact discovered
path, active language and occurrence count.

OGP owns the reusable workflow implementation. Your site owns the caller YAML and `.OpenGuidePlatform/settings.yaml`. Callers are recorded separately from checksum-managed adapters and skills. Updates also migrate callers from older installations that checksum-managed the whole file, preserving site edits when their references can be recognised safely.

Install/update recognises literal job-level calls to `guide-site-build.yaml` and `guide-site-close-pr.yaml` in `.github/workflows/*.yaml` and `*.yml`. Existing calls must use the installed release tag (or the selected release on first installation). Updates change only these release references, preserving comments, triggers, inputs and secret mappings. Flow-style calls, aliases, unsupported refs, missing recorded callers and conflicting versions stop for manual reconciliation before installation changes. An unrelated existing `main.yaml` is never overwritten to create a starter.

Install the official locking extension before adoption:

```powershell
gh extension install github/gh-actions-lock
```

The installer runs scoped `gh actions-lock --no-narrow --no-migrate-local-actions --no-interactive` and `--verify-local` for the callers, retaining existing unrelated locks. Locking may add its onboarding comment to a caller. A failure rolls back the caller, dependency, lockfile and managed-file changes. `-WhatIf` only previews the plan; it does not run locking. Commit caller and lockfile changes with the coordinated platform update. If you change caller dependencies yourself, regenerate and review the lockfile before committing. The tool locks supported action dependencies. GitHub currently excludes reusable-workflow references, so a caller containing only reusable-workflow jobs may produce no actions.lock file. That does not block installation or upgrade. OGP still updates caller release references together with the native dependency and installation record. Offline verification is not proof of reusable-workflow coverage or live repository enforcement.

Approve production deployment separately. A coordinated native module release must be published before installation. Independently managed agent enforcement still requires external setup; a passing preview does not mean those controls are installed.

## Windows symbolic links

Enable Windows Developer Mode or use an account with symbolic-link privileges. Set:

```powershell
git config --global core.symlinks true
```

For an existing platform-managed clone, check the instruction files:

```powershell
Get-Item AGENTS.md, CLAUDE.md | Select-Object Name, LinkType, Target
```

Both should be `SymbolicLink` pointing to `.agents/agents.md`. If Git checked them out as plain files containing that path, preserve any local edits first, then recreate the tracked links:

```powershell
git restore --source=HEAD --worktree -- AGENTS.md CLAUDE.md
```

If they remain plain pointer files, remove only those two unchanged pointer files and repeat the restore. Keep `.agents/agents.md`; it contains the actual instructions. This recovery applies when the repository already tracks the two files as links.
