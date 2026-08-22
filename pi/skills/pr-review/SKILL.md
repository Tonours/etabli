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
- Parent pins `gh pr diff` once to a non-empty temp file, then Logic hunter
  via `scripts/pi-review-hunter` (or the argv in `workflow/skills/review.md`).
  Spawn/nonzero → `HUNTER_SPAWN_UNAVAILABLE`. Timeout → `HUNTER_TIMEOUT`.
  Either sentinel is a hard stop. Spec runs in the parent after Logic
  (`spec: parent`), or `spec: n/a`.
- `GO` forbidden if a runtime deciding-code row is empty or `not run`, or if
  `isolation: none`.
