---
description: Autonomously fix failing GitHub PR CI through gh CLI. Use only when explicitly invoked; not for local failures or CI design.
disable-model-invocation: true
argument-hint: [PR number, optional; defaults to current branch]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion, Agent]
---
<!-- GENERATED:adapter-sync:start -->
skill: ci-fix
harness: claude
canonical: workflow/skills/ci-fix.md
description: Autonomously fix failing GitHub PR CI through gh CLI. Use only when explicitly invoked; not for local failures or CI design.
pointer: Adapter for the `ci-fix` skill. Read and follow the shared contract in `workflow/skills/ci-fix.md`. If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.
<!-- GENERATED:adapter-sync:end -->

# CI Fix

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/ci-fix.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:

- Use only when the user explicitly asks to fix CI until green.
- This command may stash, checkout, rebase, commit, and push only within the
  shared contract's safeguards.
- Never plain `--force`.
