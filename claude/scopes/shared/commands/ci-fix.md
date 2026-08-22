---
description: Autonomously fix failing GitHub PR CI through gh CLI
argument-hint: [PR number, optional; defaults to current branch]
allowed-tools: [Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion, Agent]
---

# CI Fix

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/ci-fix.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:

- Use only when the user explicitly asks to fix CI until green.
- This command may stash, checkout, rebase, commit, and push only within the
  shared contract's safeguards.
- Never plain `--force`.
