---
name: adversary
description: Challenge PLAN.md or diffs using the shared risk-tiered review contract.
---

# Adversary

Follow the shared contract in `workflow/skills/adversary.md`. The routing map
`workflow/spec.md` wins on conflict; open it only when the route or a gate is
in doubt.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Contract

Read and follow `workflow/skills/adversary.md` (plan mode **and** code-diff mode).

Rules:
- `PLAN.md` remains the only active execution artifact in plan mode.
- Code-diff mode follows `workflow/skills/adversary.md` runner independence:
  **small** skips it; **standard** accepts cross-model or two fresh independent
  same-family samples; **high-risk** requires cross-model. Required passes run
  after Logic+Spec lead review; a single same-family pass cannot replace them.
- Name `adversary_model` (or `same-family-pass: double-sample` + run ids).
- High findings: accept/reject via cross-model (or second sample), not the
  implementer alone.
- Plan-mode adversary is required before autonomous implementation completion.
- Use `review` for the primary post-implementation code review; code-diff
  adversary is the independent second pass on the same cumulative diff.
