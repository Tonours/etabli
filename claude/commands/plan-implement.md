---
description: Plan, review, then implement only when PLAN.md is READY
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Implement

User request: $ARGUMENTS

Follow `workflow/spec.md`.

1. If `$ARGUMENTS` is present, run the `plan-loop` behavior first.
2. If not, read existing `PLAN.md`.
3. Never implement from `DRAFT` or `CHALLENGED`.
4. If the plan is not `READY`, stop with blockers and next action.
5. If `READY`, implement plan steps in order with minimal scope-bound changes.
6. If facts invalidate the plan, update `PLAN.md` before continuing.
7. Run focused checks.
8. Return files changed, validation, risks, and final status.

Do not ask for confirmation once `READY`. Do not create `REVIEW.md`.
