---
name: pr-qa
description: Create a QA impact analysis and executable PR test plan.
---

# PR QA

Read and follow the shared contract in `workflow/skills/pr-qa.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


Rules:
- Use `gh` for GitHub.
- Generate a read-only QA plan.
- Do not comment, approve, edit, checkout, or merge the PR.
