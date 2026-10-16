---
name: ci-fix
description: Fix failing GitHub PR CI through gh CLI. Use when PR CI is red and should go green; not for local test failures or CI design.
---
<!-- GENERATED:adapter-sync:start -->
skill: ci-fix
harness: pi
canonical: workflow/skills/ci-fix.md
name: ci-fix
description: Fix failing GitHub PR CI through gh CLI. Use when PR CI is red and should go green; not for local test failures or CI design.
pointer: Adapter for the `ci-fix` skill. Read and follow the shared contract in `workflow/skills/ci-fix.md`. If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# CI Fix

Read and follow the shared contract in `workflow/skills/ci-fix.md`.

If the contract is missing in the workspace, try `~/.pi/agent/` then `~/.claude/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use when PR CI should go green.
- This skill may stash, checkout, rebase, commit, and push only within the
  shared contract's safeguards.
- Never plain `--force`.
