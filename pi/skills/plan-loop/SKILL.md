---
name: plan-loop
description: Create/review PLAN.md and stop at CHALLENGED or READY
---

# Plan Loop

Follow `workflow/spec.md`.

1. Inspect `git status --short` and relevant files.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad/risky work.
4. Set `Status: DRAFT` first.
5. Critique scope, steps, checks, assumptions, and risks.
6. Update `PLAN.md` in place to `CHALLENGED` or `READY`.
7. Ask only narrow blocking questions.
8. Return final status, blockers if any, and next action.

Rules:
- Do not implement.
- Do not create `REVIEW.md`.
- Do not ask whether to implement next.
