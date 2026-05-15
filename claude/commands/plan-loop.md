---
description: Create/review PLAN.md and stop at CHALLENGED or READY
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Loop

User request: $ARGUMENTS

Follow `workflow/spec.md`.

1. Inspect repo state and relevant files.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad/risky work.
4. Set `Status: DRAFT`, critique it, then update in place to `CHALLENGED` or `READY`.
5. Ask only narrow blocking questions.
6. Return final status, blockers if any, and next action.

Do not implement. Do not create `REVIEW.md`.
