---
name: adversary
description: Challenge PLAN.md or diffs; code-diff mode requires cross-model review.
---

# Adversary

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/adversary.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Contract

Read and follow `workflow/skills/adversary.md` (plan mode **and** code-diff mode).

Rules:
- `PLAN.md` remains the only active execution artifact in plan mode.
- Code-diff mode runs after break-first + plan-fit review; independence gate is
  **cross-model default**, or documented **double-sample**. A single same-family
  pass is `blocked` (full autonomy).
- Name `adversary_model` (or `same-family-pass: double-sample` + run ids).
- High findings: accept/reject via cross-model (or second sample), not the
  implementer alone.
- Plan-mode adversary is required before autonomous implementation completion.
- Use `review` for the primary post-implementation code review; code-diff
  adversary is the independent second pass on the same cumulative diff.
