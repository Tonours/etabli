---
name: adversary
description: Adversarial review of the current PLAN.md. Use after plan-loop and before implementation to catch blockers, weak assumptions, missing checks, edge cases, and plan drift. Keeps PLAN.md as the only active artifact.
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

Read and follow `workflow/skills/adversary.md`.

Rules:
- `PLAN.md` remains the only active execution artifact.
- The adversary pass is required before autonomous implementation completion.
- Use `review` for post-implementation code review; this skill reviews the plan
  before implementation.
