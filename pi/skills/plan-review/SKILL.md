---
name: plan-review
description: Critique an implementation plan before execution and challenge assumptions
---

# Plan Review

Use this before implementation to stress-test a plan and harden `PLAN.md`.
This flow ends after the critique pass. It updates the plan, returns the verdict, and stops.

1. Read `./PLAN.md` and resolve the plan template from the first existing file in this order:
   - `./PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE.md`
2. Validate first: is the goal clear, measurable, and within scope?
3. Challenge assumptions:
   - What is assumed about inputs, environment, data shape, concurrency, and failure modes?
   - Which assumptions are risky/unproven?
4. Identify missing risks and edge cases:
   - rollback points
   - irreversible actions
   - permissions/security boundaries
   - backward compatibility and migration concerns
5. Verify execution order:
   - does each step depend on required state?
   - can risky steps be moved later/split?
6. Update `PLAN.md` in place:
   - simplify scope if needed
   - split into smaller verify-able slices
   - add explicit checks before each risky step
   - record the key deltas in `Review Changes`
   - set `Status: CHALLENGED` if important issues remain
   - set `Status: READY` if the plan is executable without major rethinking
7. If the final status is `READY`, stop at the reviewed plan and point to `/skill:implement` as the next step
8. Return a short verdict plus the highest-impact changes made to `PLAN.md`

Rules:
- do NOT implement code in this skill
- do NOT ask for implementation confirmation; return the reviewed status and next command instead
- never create `REVIEW.md`
- preserve the template structure
- keep the plan short, decisive, and implementation-ready
