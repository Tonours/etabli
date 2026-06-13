---
description: Plan, review, then implement only when PLAN.md is READY
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Plan Implement

User request: $ARGUMENTS

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
   - `PLAN_TEMPLATE.md`
   - `PLAN_TEMPLATE_FULL.md`
2. If one of those files is missing in the current workspace, fall back to the Claude shared copies when this command is loaded through `~/.claude/commands`:
   - `../workflow/spec.md`
   - `../workflow/plan-archive.md`
   - `../PLAN_TEMPLATE.md`
   - `../PLAN_TEMPLATE_FULL.md`
3. If those are unavailable, fall back to the Etabli repo copies when this command is loaded from the repo target path:
   - `../../workflow/spec.md`
   - `../../workflow/plan-archive.md`
   - `../../PLAN_TEMPLATE.md`
   - `../../PLAN_TEMPLATE_FULL.md`
4. If any fallback files exist, read them and continue. Do not tell the user the template/spec is missing.
5. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

1. If `$ARGUMENTS` is present, run the `plan-loop` behavior first.
2. If not, read existing `PLAN.md`.
3. Never implement from `DRAFT` or `CHALLENGED`.
4. If the plan is not `READY`, stop with blockers and next action.
5. If `READY`, implement plan steps in order with minimal scope-bound changes.
6. If facts invalidate the plan, update `PLAN.md` before continuing.
7. Run focused checks.
8. If implementation and checks completed, archive the final plan in `docs/plan/YYYYMMDD-short-slug.md` using `workflow/plan-archive.md`; distill it as memory, do not raw-copy `PLAN.md`.
9. Return files changed, validation, risks, archive path, and final status.

Do not ask for confirmation once `READY`. Do not create `REVIEW.md`.
