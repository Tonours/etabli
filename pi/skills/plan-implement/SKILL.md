---
name: plan-implement
description: Create/review PLAN.md and implement it only when the plan is READY
---

# Plan Implement

Use this when the user wants planning, critique, and implementation chained in one flow.
This is one uninterrupted flow: once `PLAN.md` reaches `READY`, continue directly into implementation in the same invocation.
Do not ask for confirmation at the handoff from planning to implementation.
If the plan is already reviewed and `READY`, use `/skill:implement` instead.

1. Check current state: `git status --short` and `git log --oneline -3`
2. If the user provided a task description, run the full `plan-loop` flow first:
   - analyze the relevant codebase area
   - resolve the plan template from the first existing file in this order:
     - `./PLAN_TEMPLATE.md`
     - `../../PLAN_TEMPLATE.md`
   - create or refresh `./PLAN.md` with `Status: DRAFT`
   - critique it and update it to `CHALLENGED` or `READY`
3. If no task description was provided:
   - read the existing `./PLAN.md`
   - if it is missing, stop and ask for a task description or a pre-existing plan
   - if it is not `READY`, critique it and update it to `CHALLENGED` or `READY`
   - if that critique lands on `READY`, continue automatically into implementation in the same flow
4. Never implement from a `DRAFT` or `CHALLENGED` plan.
5. If `PLAN.md` is not `READY`, stop and return the blocker(s) plus the highest-impact plan changes still required.
6. If `PLAN.md` is `READY`, implement immediately and strictly from it:
   - follow the `Execution Plan` order
   - keep scope bounded to the plan
   - if new facts invalidate the plan, update `PLAN.md` first and restore `Status: READY` before continuing
7. Validate with the focused checks in `Validation` plus the smallest relevant tests/typechecks for touched code.
8. Return:
   - final `PLAN.md` status
   - files changed
   - validation run
   - remaining risks / follow-ups

Rules:
- do NOT skip the critique pass when creating or refreshing a plan
- do NOT ask for confirmation once planning/review reaches `READY`; continue automatically unless blocked by missing critical context
- do NOT widen scope during implementation
- never create `REVIEW.md`
- keep changes minimal and verification-focused
