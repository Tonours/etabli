---
description: Create/review PLAN.md then implement it only when the plan is READY
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Implement

User request: $ARGUMENTS

Use `/implement` instead when an existing `PLAN.md` is already reviewed and `READY`.

## Your task

1. If `$ARGUMENTS` is present, run the full `plan-loop` flow first:
   - inspect the current repository state and analyze the relevant codebase area
   - resolve the plan template from the first existing file in this order and keep it as the exact base structure:
     - `./PLAN_TEMPLATE.md`
     - `./claude/PLAN_TEMPLATE.md`
     - `~/.claude/PLAN_TEMPLATE.md`
   - create or refresh `./PLAN.md` with `Status: DRAFT`
   - critique it and update it to `CHALLENGED` or `READY`
2. If `$ARGUMENTS` is empty:
   - read the existing `./PLAN.md`
   - if it is missing, stop and ask for a task description or a pre-existing plan
   - if it is not `READY`, critique it and update it to `CHALLENGED` or `READY` before deciding whether implementation can start
3. Never implement from a `DRAFT` or `CHALLENGED` plan.
4. If `PLAN.md` is not `READY`, stop and return the blocker(s) plus the highest-impact plan changes still required.
5. If `PLAN.md` is `READY`, implement strictly from it:
   - follow the `Execution Plan` order
   - keep scope bounded to the plan
   - if new facts invalidate the plan, update `PLAN.md` first and re-establish `Status: READY` before continuing
6. Validate with the focused checks in `PLAN.md` plus the smallest directly relevant tests/typechecks for touched code.
7. Never create `REVIEW.md`.
8. Return:
   - final `PLAN.md` status
   - files changed
   - validation run
   - remaining risks / follow-ups

If critical context is missing, ask only the narrowest blocking question.
