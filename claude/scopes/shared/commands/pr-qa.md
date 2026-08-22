---
description: Generate a QA impact analysis and test plan for a GitHub PR
argument-hint: [PR URL/number/repo alias]
allowed-tools: [Read, Glob, Grep, AskUserQuestion]
---

# PR QA

User request: $ARGUMENTS

Read and follow the shared contract in `workflow/skills/pr-qa.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `gh` for GitHub.
- Generate a read-only QA plan.
- Do not comment, approve, edit, checkout, or merge the PR.
