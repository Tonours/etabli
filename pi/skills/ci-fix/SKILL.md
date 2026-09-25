---
name: ci-fix
description: Fix failing GitHub PR CI through gh CLI. Use only when explicitly asked via /skill:ci-fix; not for local test failures or CI design.
disable-model-invocation: true
---
<!-- GENERATED:adapter-sync:start -->
skill: ci-fix
harness: pi
canonical: workflow/skills/ci-fix.md
name: ci-fix
description: Fix failing GitHub PR CI through gh CLI. Use only when explicitly asked via /skill:ci-fix; not for local test failures or CI design.
pointer: Adapter for the `ci-fix` skill. Read and follow the shared contract in `workflow/skills/ci-fix.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# CI Fix

Read and follow the shared contract in `workflow/skills/ci-fix.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use only when explicitly invoked or clearly requested.
- This skill may stash, checkout, rebase, commit, and push only within the
  shared contract's safeguards.
- Never plain `--force`.
