# First-time guide-site setup

This page is for the maintainer adopting OpenGuidePlatform into an existing guide site. Contributors to an already adopted site can use the [README commands](../../readme.md#everyday-use).

Adoption is currently a preview migration. Keep it on a branch and verify the site's existing content, design, routes and downloads before accepting it. The installer does not create a new website or rewrite the guide structure.

## Use the existing Hugo source

No site policy file is required. The default source is `site/`; supply `-SourcePath` for another Hugo directory. Keep language enablement in Hugo YAML and content metadata in the existing bundles.

Prepare discovers guide roots, editions, translation bodies, PDF resources and Hugo public URLs. It checks the root, history and translations scaffolding for active guide languages. The resulting inventory is build evidence under `.processing/`, not a second set of content declarations to maintain.

Keep destination settings in `.OpenGuidePlatform/delivery.yaml`. Installation writes its record and resolver under `.OpenGuidePlatform/`; the thin root `build.ps1` remains the command people run.

## Install and integrate

Preserve existing edits and create a review branch, then run the install command in the [README](../../readme.md#install-or-update).

The installer refuses conflicting existing files, including build scripts, workflow callers and agent instructions. Review each conflict and migrate the existing behaviour deliberately before retrying. Do not remove bespoke instructions, workflows or content merely to make installation succeed.

The wrapper must already have a `site/go.mod` (or the equivalent under its configured source folder) and its Hugo module import in YAML. The installer updates the native module identity, version and checksums together with the platform. Unsupported YAML forms or locally modified managed files stop installation for review; the installer does not reformat the whole configuration. Local-only module replacement destinations are preserved.

Review the resulting module/configuration diff, build adapter, installation record, skills and instructions. Build preview and production output. Check guide bodies, language fallbacks, links, downloads and the site's appearance against the existing site.

The generated workflow initially validates a preview target. To deploy, configure the shared workflow's site URL, target, preview environment and explicitly mapped hosting secret. Add the [shared close-PR workflow](../../.github/workflows/guide-site-close-pr.yaml) through a site-owned caller. The platform's [sample cleanup caller](../../.github/workflows/sample-close-pr.yaml) illustrates this; its hosting destination and secret belong to the sample, not your site.

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