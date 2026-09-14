# Guide-site agent controls

This component provides the independent repository evaluator. Instruction shims guide agents; they do not enforce policy. Client settings and an independently administered required check are separate controls. Nothing in this package installs machine policies, changes permissions or configures GitHub.

## Repository evaluator

Run `RepositoryGovernance/Test-GuideRepositoryGovernance.ps1` from an administrator-controlled platform checkout outside the candidate workspace. Supply an external policy file, its independently selected SHA256, the repository identity and exact candidate commit. Its baseline commit must exist in the candidate Git object database. Keep the evaluator, policy digest and required-check selection outside contributor control.

```powershell
& $trustedEvaluator -WorkspaceRoot $candidateCheckout -CandidateCommit $candidateCommit `
    -TrustedPolicyPath $trustedPolicy -ExpectedPolicySha256 $trustedPolicyDigest `
    -Repository $repository
```

The policy has exactly these fields:

```json
{
  "schemaVersion": 1,
  "repository": "owner/guide-site",
  "baselineCommit": "<reviewed 40-character commit>",
  "protectedPaths": ["site/layouts", "site/assets"],
  "protectedFileNames": ["staticwebapp.config*.json"]
}
```

Baseline and candidate are read through `git ls-tree`; the evaluator does not check out or execute candidate code, filters or tests. It compares additions, deletions, object identities and file modes. Build adapters, policy/installation files, agent-control directories, module manifests, Hugo configuration and nested agent instruction files are always protected. The supplied policy adds wrapper and protected guide/PDF paths. Editorial files outside those selectors remain editable.

Exit 0 and `outcome: pass` mean the exact commit has no protected changes against that baseline. Exit 1 with `outcome: blocked` lists the files requiring maintainer review. Missing commits, changed policy digests, candidate-owned policy/evaluator paths and invalid input fail instead of producing a pass. The caller must also fail when the process fails or no report is returned. No candidate-authored approval flag can waive a finding.

This gate is deliberately conservative: legitimate technical changes need an external baseline update after review. It complements publication and artifact validation; it does not replace them or inspect the meaning of editorial prose. A deployed required check has not been configured by this work.

## Managed client boundaries

| Client | Applicable control | Remaining acceptance |
|---|---|---|
| Codex local app/CLI/IDE | Administrator-delivered `requirements.toml`, allowlisted permission profiles and protected paths with read-only filesystem access | Verify the exact client/OS and external tool/MCP access before claiming enforcement |
| Claude Code | Managed permission rules plus sandbox filesystem write restrictions and failure when sandboxing is unavailable | Native Windows has no sandbox; use a supported environment for subprocess isolation and verify bypass/indirect-tool cases |
| Copilot CLI | Managed permission rules and supported sandbox policy; machine policy hooks can provide additional feedback | Windows per-path sandbox denies are unsupported; hooks time out open, so neither is universal file-write enforcement |
| Copilot cloud/IDE | Shared instructions and supported hooks for feedback | Do not assume CLI-managed controls apply to these clients; the independent repository gate remains necessary |

Codex documents managed profiles separately from repository defaults. A profile can restrict protected paths to `read`; repository-local configuration is not administrator policy. See [managed configuration](https://learn.chatgpt.com/docs/enterprise/managed-configuration) and [profile reference](https://learn.chatgpt.com/docs/config-file/config-reference).

Claude's `Edit` rules do not cover arbitrary subprocess file access. Sandbox restrictions address subprocesses on supported systems, but native Windows is unsupported and excluded-command settings need specific review. See [permissions](https://code.claude.com/docs/en/permissions) and [sandbox controls](https://code.claude.com/docs/en/sandboxing).

Copilot CLI supports managed `Edit`/`Write` rules and sandbox policies, with platform limits. Its Windows backend rejects per-path sandbox denied paths; command hooks fail open on timeout even when administrator deployed. See [managed CLI configuration](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference) and [hook behavior](https://docs.github.com/en/copilot/reference/hooks-reference).

These are documented capability boundaries, reviewed 2026-09-13. Local regression tests prove the repository evaluator's behavior; they are not live client/OS enforcement tests. Managed-client installation and live bypass tests remain unverified and are not performed by bootstrap.