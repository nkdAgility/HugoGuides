# First-time guide-site setup

This page is for the maintainer adopting OpenGuidePlatform into an existing guide site. Contributors to an already adopted site can use the [README commands](../../readme.md#everyday-use).

Adoption is currently a preview migration. Keep it on a branch and verify the site's existing content, design, routes and downloads before accepting it. The installer does not create a new website or infer publication policy.

## Prepare the site policy

Create `guide-site.policy.json` in the guide-site repository root. Use the [reference site's policy](../../examples/reference-guide-site/guide-site.policy.json) as a worked example and the [policy contract](../../system/OpenGuidePlatform.PowerShell.Core/Contracts/README.md) for field meanings. Validate against the [site-policy schema](../../system/OpenGuidePlatform.PowerShell.Core/Contracts/site-policy.schema.json).

Describe your own site:

1. Its identity, Hugo source folder, required wrapper files, routes and translation keys.
2. Every guide and edition, its source language, and each translation's intended state: web, PDF-only, fallback, scaffold or excluded.
3. Existing download source paths, their `publishedPaths` in the built site, and whether each PDF is supplied, generated or protected.
4. Production exclusions, protected content and the permitted publishing operations.

Paths must reflect the existing site. Most paths are repository-relative; edition paths are relative to the guide's content root and download `path` values are relative to the edition. Each download's `publishedPaths` lists its existing public file paths relative to the built site, without a leading slash; for example `downloads/guide.en.pdf`. Record those from the current site/baseline, preserving URLs rather than deriving them from content folder names. Do not copy the sample's guide names, content paths or publication rules unchanged. Test fixtures are incomplete examples, not installation policies.

Have the site's maintainers review these declarations. A policy file describes requirements; it does not install independent enforcement or grant an agent maintainer authority.

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