# Claude

This folder contains Claude Code-specific artifacts and documents.

## Commands

- `commands/create-plan.md` creates or refreshes `PLAN.md` from `PLAN_TEMPLATE.md` with `Status: DRAFT`
- `commands/plan-review.md` reviews `PLAN.md`, hardens it in place, and marks it `CHALLENGED` or `READY`
- `commands/plan-loop.md` chains `plan` then `plan-review` in a single interactive loop

`verify` is no longer part of this workflow.
