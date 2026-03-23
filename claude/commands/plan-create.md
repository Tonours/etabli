---
description: Create PLAN.md from PLAN_TEMPLATE.md with Status DRAFT
argument-hint: <task description>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan

User request: $ARGUMENTS

## Your task

1. Inspect the current repository state and recent commits.
2. Analyze the relevant codebase area before planning.
3. Resolve the plan template from the first existing file in this order and preserve its structure exactly:
   - `./PLAN_TEMPLATE.md`
   - `./claude/PLAN_TEMPLATE.md`
   - `~/.claude/PLAN_TEMPLATE.md`
4. Create or refresh `./PLAN.md` from that template.
5. Set `Status: DRAFT`.
6. Fill the relevant sections with concrete project-specific content.
7. Keep the plan concise. If something important is unknown, make it explicit in `Open Questions`.
8. Once `PLAN.md` is reviewed to `READY`, continue with `/implement`.
9. Do not implement code.

If critical context is missing, ask only the narrowest blocking question.
