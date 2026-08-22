---
description: Review a GitHub PR through gh CLI with human-in-the-loop posting
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, AskUserQuestion, Agent]
---

# PR Review

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/pr-review.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `gh` for GitHub unless the user explicitly overrides this.
- Default is read-only.
- Do not post comments or approve without explicit user approval.
