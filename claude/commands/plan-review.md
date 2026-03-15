---
description: Stress-test PLAN.md and update it in place to CHALLENGED or READY
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Review

## Your task

1. Read `./PLAN.md` and resolve the plan template from the first existing file in this order:
   - `./PLAN_TEMPLATE.md`
   - `./claude/PLAN_TEMPLATE.md`
2. Treat `./PLAN.md` as a draft that must be challenged, not defended.
3. Check:
   - goal clarity and scope boundaries
   - risky assumptions
   - missing risks and edge cases
   - execution order
   - verification quality
4. Update `PLAN.md` in place:
   - preserve the template structure
   - tighten scope if needed
   - split risky steps into smaller verifiable slices
   - record key deltas in `Review Changes`
   - set `Status: CHALLENGED` if important issues remain
   - set `Status: READY` if the plan is executable without major rethinking
5. If the final status is `READY`, the next implementation step is `/implement`.
6. Never create `REVIEW.md`.
7. Return the final status and the highest-impact changes made.

If critical context is missing, ask only the narrowest blocking question.
