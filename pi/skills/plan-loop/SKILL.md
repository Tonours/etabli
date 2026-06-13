---
name: plan-loop
description: Create/review PLAN.md and stop at CHALLENGED or READY
---

# Plan Loop

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. If one of those files is missing in the current workspace, fall back to the Pi agent shared copies when this skill is loaded through `~/.pi/agent/skills`:
   - `../../workflow/spec.md`
   - `../../PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE_FULL.md`
3. If those are unavailable, fall back to the Etabli repo copies when this skill is loaded from the repo target path:
   - `../../../workflow/spec.md`
   - `../../../PLAN_TEMPLATE.md`
   - `../../../PLAN_TEMPLATE_FULL.md`
4. If any fallback files exist, read them and continue. Do not tell the user the template/spec is missing.
5. If all workspace and fallback copies are missing, create `PLAN.md` from the template shape embedded in this skill and report the missing source paths as a warning, not as a blocker.

Embedded fallback shape:

```md
# PLAN.md

## Meta
- Subject:
- Status: DRAFT | CHALLENGED | READY
- Last revised:
- Archive: pending until implemented and validated

## Goal

## Acceptance Criteria
-

## Scope
### In
-

### Out
-

## Facts And Assumptions
### Observed Facts
-

### Assumptions
- None / ...

## Steps
1.
2.
3.

## Checks
- command:
  - expected:
  - last run:

## Risks
- None / ...

## Decision Log
- YYYY-MM-DD:

## Open Questions
- None / ...

## Notes / Handoff
-
```

1. Inspect `git status --short` and relevant files.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad/risky work.
4. Set `Status: DRAFT` first.
5. Critique scope, steps, checks, assumptions, and risks.
6. Update `PLAN.md` in place to `CHALLENGED` or `READY`.
7. Ask only narrow blocking questions.
8. Return final status, blockers if any, and next action.

Rules:
- Do not implement.
- Do not create or update `docs/plan/` archives during planning.
- Do not create `REVIEW.md`.
- Do not ask whether to implement next.
