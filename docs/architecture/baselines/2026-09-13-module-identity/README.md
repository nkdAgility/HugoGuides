# Repository rename: historical module resolution

All three existing consumer versions of `github.com/nkdAgility/HugoGuides/module` resolved successfully after the repository rename. Each of six downloads used its own empty module cache and GOPATH; the proxy cases used `https://proxy.golang.org` with no direct fallback, and the direct cases used `GOPROXY=direct`. Ambient Go workspace/private-module overrides were disabled for these processes only. No consumer checkout or Git configuration was changed.

| Consumer | Existing version | Proxy | Direct Git |
|---|---|---|---|
| KanbanGuides | v0.8.4 | Pass | Pass |
| the-safe-delusion | v0.6.8 | Pass | Pass |
| ScrumGuide-ExpansionPack | v0.8.3 | Pass | Pass |

[Machine-readable results](historical-resolution.json) retain module and go.mod checksums, native exit status and returned origin evidence. The proxy and direct checksums match for each version. This verifies historical resolution, not adoption or rendering equivalence.

The canonical new module is `github.com/nkdAgility/OpenGuidePlatform/system/OpenGuidePlatform.Hugo.Guides`. Its releases need `system/OpenGuidePlatform.Hugo.Guides/v...` tags because Go prefixes version tags with the module subdirectory ([Go module reference](https://go.dev/ref/mod#vcs-version)). Canonical publication and clean-cache acceptance remain separate from these historical checks.
## Canonical commit resolution

The canonical module at source commit `9dc4ad6833ad032e30773c613db8092b9c19d92a` also resolved in separate fresh caches through direct Git and the Go proxy. Both returned `v0.0.0-20260913175623-9dc4ad6833ad` and matching checksums; see [canonical results](canonical-resolution.json). This uses Go's normal commit-to-pseudo-version resolution. It does not substitute for verification of the eventual named release tag.