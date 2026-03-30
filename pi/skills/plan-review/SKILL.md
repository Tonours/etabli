---
name: plan-review
description: Critique an implementation plan before execution and challenge assumptions
---

# Plan Review

Use this before implementation to stress-test a plan and harden `PLAN.md`.
This flow ends after the critique pass. It updates the plan, returns the verdict, and stops.

1. Read `./PLAN.md` and resolve the plan template from the first existing file in this order:
   - `./PLAN_TEMPLATE.md`
   - `~/.claude/PLAN_TEMPLATE.md`
2. Validate first: is the goal clear, measurable, and within scope?
3. Challenge assumptions:
   - What is assumed about inputs, environment, data shape, concurrency, and failure modes?
   - Which assumptions are risky/unproven?
4. Challenge the measurement contract:
   - Is the expected outcome observable?
   - Are the blocking checks explicit?
   - Are trace points, stop triggers, and escalation triggers clear enough to guide execution?
5. Challenge the execution contract:
   - Are non-goals explicit?
   - Are invariants and done criteria concrete?
   - Do slices name files/areas, checks, and rollback points clearly enough to execute without reinterpretation?
6. Identify missing risks and edge cases:
   - rollback points
   - irreversible actions
   - permissions/security boundaries
   - backward compatibility and migration concerns
7. Verify execution order:
   - does each step depend on required state?
   - can risky steps be moved later/split?
8. Update `PLAN.md` in place:
   - simplify scope if needed
   - tighten the measurement contract if success/stop/escalation criteria are weak
   - tighten the execution contract if slices/files/checks/invariants/done/rollback are weak
   - split into smaller verify-able slices
   - add explicit checks before each risky step
   - record the key deltas in `Review Changes`
   - set `Status: CHALLENGED` if important issues remain
   - set `Status: READY` if the plan is executable without major rethinking
9. If the final status is `READY`, stop at the reviewed plan and point to `/skill:implement` as the next step
10. Return a short verdict plus the highest-impact changes made to `PLAN.md`

Rules:
- do NOT implement code in this skill
- do NOT ask for implementation confirmation; return the reviewed status and next command instead
- never create `REVIEW.md`
- preserve the template structure
- keep the plan short, decisive, and implementation-ready
