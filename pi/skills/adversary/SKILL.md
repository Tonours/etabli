---
name: adversary
description: Adversarial review of PLAN.md (plan mode) or of the implementation diff (code-diff mode). Cross-model or documented double-sample; single same-family pass is forbidden.
---

# Adversary

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/adversary.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/skills/adversary.md`
   - `PLAN.md`
2. If the workflow spec is missing in the current workspace, fall back to the Pi
   agent shared copy when this skill is loaded through `~/.pi/agent/skills`:
   - `../../workflow/spec.md`
   - `../../workflow/skills/adversary.md`
3. If unavailable, fall back to the Etabli repo copy when this skill is loaded
   from the repo target path:
   - `../../../workflow/spec.md`
   - `../../../workflow/skills/adversary.md`
4. If a fallback spec exists, read it and continue. Do not report it missing.

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
