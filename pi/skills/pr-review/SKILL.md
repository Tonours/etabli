---
name: pr-review
description: Review GitHub PRs with gh CLI; posting needs human approval.
---

# PR Review

Read and follow the shared contract in `workflow/skills/pr-review.md` and the
rubric in `workflow/review-rubric.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Rules

- Use `gh` for GitHub unless the user explicitly overrides this.
- Default is read-only.
- Do not post comments or approve without explicit user approval.
- Break-first then plan-fit/intent-fit; lens + deciding-code tables mandatory.
- `GO` forbidden if a runtime deciding-code row is empty or `not run`.
