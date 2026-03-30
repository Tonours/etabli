---
name: plan
description: Create a structured implementation plan before writing code
---

# Plan

Create a detailed implementation plan.

1. Check current state: `git status --short` and `git log --oneline -3`
2. Analyze the codebase to understand what needs to change
3. Resolve the plan template in this order and use the first existing file as the exact base structure for `./PLAN.md`:
   - `./PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE.md`
4. Write `./PLAN.md`:
   - preserve the template section order
   - set `Status: DRAFT`
   - fill every relevant section with concrete project-specific content
   - make the phase-0 measurement contract explicit: outcome, blocking checks, trace points, stop/escalation triggers, diff budget
   - make the phase-1 execution contract explicit: non-goals, invariants, done criteria, ordered slices with files/areas, checks, rollback points
   - keep it concise; if something is unknown, make it explicit in `Open Questions`
   - include likely files/components under `Relevant Context`, not as a free-form dump
5. Do NOT write code yet
6. `PLAN.md` becomes executable only after `/skill:plan-review` updates it and marks it `READY`
7. If the user wants to continue from a reviewed `READY` plan, use `/skill:implement`
8. If the user wants plan creation and critique chained together, use `/skill:plan-loop`
9. If the user wants planning, critique, and implementation chained together, use `/skill:plan-implement`
