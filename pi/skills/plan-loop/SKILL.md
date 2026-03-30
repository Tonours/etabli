---
name: plan-loop
description: Create and harden PLAN.md in one interactive flow until it lands in CHALLENGED or READY
---

# Plan Loop

Use this when the user wants plan creation and plan critique chained together.
This flow ends at the reviewed plan. It does not continue into implementation.
Do not ask for implementation confirmation at the end; return the final reviewed status and stop.

1. Check current state: `git status --short` and `git log --oneline -3`
2. Analyze the relevant codebase area
3. Resolve the plan template from the first existing file in this order:
   - `./PLAN_TEMPLATE.md`
   - `~/.claude/PLAN_TEMPLATE.md`
4. Create or refresh `./PLAN.md` from the template with `Status: DRAFT`
5. Run an explicit critique pass against that draft:
   - challenge scope
   - challenge the measurement contract
   - challenge the execution contract
   - challenge assumptions
   - check edge cases and risks
   - verify execution order
6. Update `./PLAN.md` in place:
   - preserve the template structure
   - record key deltas in `Review Changes`
   - refuse `READY` if outcome/checks/trace/stop/escalation criteria remain vague
   - refuse `READY` if slices/files/checks/invariants/done criteria/rollback points remain vague
   - set `Status: CHALLENGED` if important issues remain
   - set `Status: READY` if the plan is executable without major rethinking
7. If critical context is missing, ask only the narrowest blocking question(s), then fold the answer back into `PLAN.md`
8. Return the final status plus the highest-impact changes made to the plan
9. If the user wants to continue later from the reviewed plan, use `/skill:implement`
10. If the user wants planning, critique, and implementation in one uninterrupted flow, use `/skill:plan-implement` instead of this skill

Rules:
- do NOT write implementation code
- do NOT ask whether to implement next; stop after returning the reviewed `PLAN.md` status
- never create `REVIEW.md`
- keep the plan concise and implementation-ready
