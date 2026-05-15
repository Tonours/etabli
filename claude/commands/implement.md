---
description: Implement the existing READY PLAN.md without rerunning planning
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Implement

Follow `workflow/spec.md`.

1. Inspect repo state.
2. Read `PLAN.md`.
3. Stop if missing, `DRAFT`, or `CHALLENGED`.
4. Implement `READY` plan steps in order.
5. Keep changes minimal and scope-bound.
6. Update `PLAN.md` only for progress or newly discovered facts.
7. Run focused checks.
8. Return files changed, validation, risks, and final status.

Do not create `REVIEW.md`.
