---
description: Implement the existing READY PLAN.md without rerunning planning
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Implement

## Your task

1. Inspect the current repository state and recent commits.
2. Read the existing `./PLAN.md`.
3. If `./PLAN.md` is missing, stop and ask for a task description with `/plan` or a pre-existing plan.
4. Never implement from a `DRAFT` or `CHALLENGED` plan.
5. If `PLAN.md` is not `READY`, stop and return the blocker(s) plus the next command to run (`/plan-review` or `/plan`).
6. If `PLAN.md` is `READY`, implement strictly from it:
   - follow the execution slices in order
   - mark the active slice in `PLAN.md`
   - load only the context needed for that slice
   - make the smallest change that advances the slice
   - run the slice checks before moving on
   - record light implementation state in `PLAN.md` (completed slices, pending checks, next recommended action)
   - decide after each slice whether to continue, correct, or replan
   - keep scope bounded to the plan
   - if new facts invalidate the plan, update `PLAN.md` first and re-establish `Status: READY` before continuing
7. Validate with the focused checks in `PLAN.md` plus the smallest directly relevant tests/typechecks for touched code.
8. Never create `REVIEW.md`.
9. If the user wants to pause and resume later from the current implementation state, use `/handoff-implement`.
10. Return:
   - final `PLAN.md` status
   - files changed
   - validation run
   - remaining risks / follow-ups

If critical context is missing, ask only the narrowest blocking question.
