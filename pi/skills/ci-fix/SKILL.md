---
name: ci-fix
description: Fix GitHub PR CI only when explicitly asked.
---

# CI Fix

Read and follow the shared contract in `workflow/skills/ci-fix.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use only when explicitly invoked or clearly requested.
- This skill may stash, checkout, rebase, commit, and push only within the
  shared contract's safeguards.
- Never plain `--force`.
