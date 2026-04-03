---
name: plan
description: Create a structured implementation plan before writing code
---

# Plan

Create a detailed implementation plan.

1. Check current state: `git status --short` and `git log --oneline -3`
2. Silently compile the user's task into a compact planning brief before analysis:
   - strip filler, hedging, and conversational wrappers
   - preserve scope, constraints, file paths, commands, and acceptance criteria
   - when useful, restate it as a short working brief with goal, constraints, known context, and expected output
   - use this compiled brief internally for the rest of the skill without asking the user to confirm or rerun anything
3. Analyze the codebase to understand what needs to change
4. Resolve the plan template in this order and use the first existing file as the exact base structure for `./PLAN.md`:
   - `./PLAN_TEMPLATE.md`
   - `~/.claude/PLAN_TEMPLATE.md`
5. Write `./PLAN.md`:
   - preserve the template section order
   - set `Status: DRAFT`
   - fill every relevant section with concrete project-specific content
   - make the phase-0 measurement contract explicit: outcome, blocking checks, trace points, stop/escalation triggers, diff budget
   - make the phase-1 execution contract explicit: non-goals, invariants, done criteria, ordered slices with files/areas, checks, rollback points
   - keep it concise; if something is unknown, make it explicit in `Open Questions`
   - include likely files/components under `Relevant Context`, not as a free-form dump
6. Do NOT write code yet
7. `PLAN.md` becomes executable only after `/skill:plan-review` updates it and marks it `READY`
8. If the user wants to continue from a reviewed `READY` plan, use `/skill:implement`
9. If the user wants plan creation and critique chained together, use `/skill:plan-loop`
10. If the user wants planning, critique, and implementation chained together, use `/skill:plan-implement`
