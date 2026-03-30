---
description: Chain plan and plan-review in one interactive flow until PLAN.md lands in CHALLENGED or READY
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Loop

User request: $ARGUMENTS

This flow ends at the reviewed plan. It does not continue into implementation.
Do not ask for implementation confirmation at the end; return the final reviewed status and stop.

## Your task

1. Inspect the current repository state and analyze the relevant codebase area.
2. Resolve the plan template from the first existing file in this order and keep it as the exact base structure:
   - `./PLAN_TEMPLATE.md`
   - `./claude/PLAN_TEMPLATE.md`
   - `~/.claude/PLAN_TEMPLATE.md`
3. Create or refresh `./PLAN.md` from that template with `Status: DRAFT`.
4. Immediately run a separate critique pass against that draft:
   - challenge scope
   - challenge the measurement contract
   - challenge the execution contract (slices, files, checks, invariants, done criteria, rollback points)
   - challenge assumptions
   - identify missing risks and edge cases
   - verify execution order and validation steps
5. Update `PLAN.md` in place:
   - preserve the template structure
   - record key deltas in `Review Changes`
   - refuse `READY` if the expected outcome, blocking checks, trace points, stop triggers, or escalation triggers stay vague
   - refuse `READY` if slices, files/areas, checks, invariants, done criteria, or rollback points stay vague
   - set `Status: CHALLENGED` if important issues remain
   - set `Status: READY` if the plan is executable without major rethinking
6. If critical context is missing, ask only the narrowest blocking question(s), then fold the answer back into `PLAN.md` and tighten it once more.
7. Never create `REVIEW.md`.
8. Do not implement code.
9. If the user wants to continue later from the reviewed plan, use `/implement`.
10. If the user wants planning, critique, and implementation in one uninterrupted flow, use `/plan-implement` instead of this command.
11. Return the final status and the highest-impact plan changes.
