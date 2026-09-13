# Runtime anchor validation

Declare `wrapper.runtimeAnchors` in the site policy as objects with `route` and `fragment`. Use the canonical rendered route (for example `/brief/`) and decoded element ID. Validate checks these declarations against the current artifact; passing observations resolve only matching static missing-anchor findings. A missing declaration, missing element or unavailable browser cannot produce an exemption.

Node.js 20 or newer and npm are required when declarations exist. The same root build operation restores the lockfile-verified Playwright package and Chromium to `.processing/browser-tools/` locally and in CI. The first run needs download access; later runs reuse the cache. Linux requires Chromium system libraries; use a supported runner image. No tools or browser settings are installed globally.

Evidence records browser/checker versions, artifact identity digest, observations and blocked HTTP/WebSocket requests. Browser page requests are served from the artifact; external requests and service workers are blocked. This is functional validation in an unprivileged build context, not an operating-system security boundary or visual approval. Artifact inventory and hashes are checked before and after observation.

The original static findings remain in `navigation-validation.json`; current browser evidence is in `runtime-anchor-validation.json`, and the combined decision is in `artifact-validation.json`.
