---
name: implement
description: Implement an existing READY PLAN.md
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

Rules:
- Do not rerun full planning.
- Do not create `REVIEW.md`.
