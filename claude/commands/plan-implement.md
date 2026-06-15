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
5. Before editing, confirm the plan has concrete checks or required evidence. If missing, stop with `CHALLENGED` and explain the missing evidence.
6. If the plan is `READY`, implement its steps in order.
7. Keep changes minimal and scope-bound.
8. If facts materially invalidate the route, scope, checks, or required evidence, stop as `plan drift detected`; update `PLAN.md` with observed facts and do not continue implementation until the plan is refreshed to `READY`.
9. Run focused checks from the plan.
10. If implementation and checks completed, archive the final plan in `docs/plan/YYYYMMDD-short-slug.md` using `workflow/plan-archive.md`; distill it as memory, do not raw-copy `PLAN.md`.
11. After the archive is written and validation is complete, delete only the current workspace root `PLAN.md`. Do not delete archived plans, fallback templates, or any nested `PLAN.md`. If archiving was skipped or failed, keep `PLAN.md` and report why.
12. Return files changed, validation, risks, archive path, deleted `PLAN.md` status, remaining risks, next action if any, and final status.

Rules:
- Do not ask for confirmation once the plan is `READY`.
- Do not create `REVIEW.md`.
