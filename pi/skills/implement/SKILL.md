---
name: implement
description: Implement an existing READY PLAN.md
---

# Implement

Use this after `/skill:plan-review` when `PLAN.md` is already `READY`.

1. Check current state: `git status --short` and `git log --oneline -3`
2. Read the existing `./PLAN.md`
3. If `PLAN.md` is missing, stop and ask for a task description with `/skill:plan` or a pre-existing plan
4. Never implement from a `DRAFT` or `CHALLENGED` plan
5. If `PLAN.md` is not `READY`, stop and return the blocker(s) plus the next command to run (`/skill:plan-review` or `/skill:plan`)
6. If `PLAN.md` is `READY`, implement strictly from it:
   - follow the execution slices in order
   - mark the active slice in `PLAN.md`
   - load only the context needed for that slice
   - make the smallest change that advances the slice
   - run the slice checks before moving on
   - record light implementation state in `PLAN.md` (completed slices, pending checks, next recommended action)
   - decide after each slice whether to continue, correct, or replan
   - keep scope bounded to the plan
   - if new facts invalidate the plan, update `PLAN.md` first and restore `Status: READY` before continuing
7. Validate with the focused checks in `Validation` plus the smallest relevant tests/typechecks for touched code
8. Return:
   - final `PLAN.md` status
   - files changed
   - validation run
   - remaining risks / follow-ups
9. If the user wants to pause and resume later from the current implementation state, use `/handoff-implement`

Rules:
- do NOT rerun full planning if a reviewed `PLAN.md` already exists
- do NOT widen scope during implementation
- never create `REVIEW.md`
- keep changes minimal and verification-focused
