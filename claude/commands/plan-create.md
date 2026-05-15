---
description: Create PLAN.md from PLAN_TEMPLATE.md with Status DRAFT
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan

User request: $ARGUMENTS

Follow `workflow/spec.md`.

1. Inspect repo state and relevant files.
2. Create or refresh `PLAN.md` from `PLAN_TEMPLATE.md`.
3. Use `PLAN_TEMPLATE_FULL.md` only for broad/risky work.
4. Set `Status: DRAFT`.
5. Fill goal, scope, steps, checks, risks, and open questions.
6. Ask only narrow blocking questions.
7. Stop without implementation.
