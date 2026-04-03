---
name: plan-review
description: Critique an implementation plan before execution and challenge assumptions
---

# Plan Review

Use this before implementation to stress-test a plan and harden `PLAN.md`.
This flow ends after the critique pass. It updates the plan, returns the verdict, and stops.

1. If the user included extra framing for the review request, silently compile it into a compact review brief first:
   - strip filler, hedging, and conversational wrappers
   - preserve scope, constraints, file paths, commands, and acceptance criteria
   - when useful, restate it as a short working brief with goal, constraints, known context, and expected output
   - use this compiled brief internally for the rest of the skill without asking the user to confirm or rewrite it
2. Read `./PLAN.md` and resolve the plan template from the first existing file in this order:
   - `./PLAN_TEMPLATE.md`
   - `~/.claude/PLAN_TEMPLATE.md`
3. Validate first: is the goal clear, measurable, and within scope?
4. Challenge assumptions:
   - What is assumed about inputs, environment, data shape, concurrency, and failure modes?
   - Which assumptions are risky/unproven?
5. Challenge the measurement contract:
   - Is the expected outcome observable?
   - Are the blocking checks explicit?
   - Are trace points, stop triggers, and escalation triggers clear enough to guide execution?
6. Challenge the execution contract:
   - Are non-goals explicit?
   - Are invariants and done criteria concrete?
   - Do slices name files/areas, checks, and rollback points clearly enough to execute without reinterpretation?
7. Identify missing risks and edge cases:
   - rollback points
   - irreversible actions
   - permissions/security boundaries
   - backward compatibility and migration concerns
8. Verify execution order:
   - does each step depend on required state?
   - can risky steps be moved later/split?
9. Update `PLAN.md` in place:
   - simplify scope if needed
   - tighten the measurement contract if success/stop/escalation criteria are weak
   - tighten the execution contract if slices/files/checks/invariants/done/rollback are weak
   - split into smaller verify-able slices
   - add explicit checks before each risky step
   - record the key deltas in `Review Changes`
   - set `Status: CHALLENGED` if important issues remain
   - set `Status: READY` if the plan is executable without major rethinking
10. If the final status is `READY`, stop at the reviewed plan and point to `/skill:implement` as the next step
11. Return a short verdict plus the highest-impact changes made to `PLAN.md`

Rules:
- do NOT implement code in this skill
- do NOT ask for implementation confirmation; return the reviewed status and next command instead
- never create `REVIEW.md`
- preserve the template structure
- keep the plan short, decisive, and implementation-ready
