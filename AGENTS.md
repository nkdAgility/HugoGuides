# Agent Instructions

## Build Verification (MANDATORY)

After **every** change to files under `module/` or `site/`, you **must** run a build and confirm it succeeds before considering the task complete.

### Build Command

```powershell
hugo build --source site --config hugo.yaml,hugo.local.yaml
```

Run from the workspace root (`c:\Users\MartinHinshelwoodNKD\source\repos\HugoGuides`).

### Pass Criteria

- Exit code **0**
- No `ERROR` lines in output
- No template parse failures

If the build fails, fix all errors before finishing. Do not report a task as done while the build is broken.
