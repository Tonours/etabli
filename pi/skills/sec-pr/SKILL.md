---
name: sec-pr
description: Audit Dependabot or security PRs; verify advisories, lock resolution, and CI.
---

# Sec PR

Read and follow the shared contract in `workflow/skills/sec-pr.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Default is read-only.
- Never trust the PR body alone.
- Never merge automatically.
