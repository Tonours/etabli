---
description: Implement the existing READY PLAN.md without rerunning planning
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion]
---

# Implement

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
2. If one of those files is missing in the current workspace, fall back to the Claude shared copies when this command is loaded through `~/.claude/commands`:
   - `../workflow/spec.md`
   - `../workflow/plan-archive.md`
3. If those are unavailable, fall back to the Etabli repo copies when this command is loaded from the repo target path:
   - `../../workflow/spec.md`
   - `../../workflow/plan-archive.md`
4. If any fallback files exist, read them and continue. Do not tell the user the workflow spec is missing.
5. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

1. Inspect repo state.
2. Read `PLAN.md`.
3. Stop if missing, `DRAFT`, or `CHALLENGED`.
4. Before editing, confirm the plan has concrete checks or required evidence. If missing, stop with `CHALLENGED` and explain the missing evidence.
5. Implement `READY` plan steps in order.
6. Keep changes minimal and scope-bound.
7. Update `PLAN.md` only for progress or newly discovered facts.
8. If facts materially invalidate the route, scope, checks, or required evidence, stop as `plan drift detected`; update `PLAN.md` with observed facts and do not continue implementation until the plan is refreshed to `READY`.
9. Run focused checks.
10. If implementation and checks completed, archive the final plan in `docs/plan/YYYYMMDD-short-slug.md` using `workflow/plan-archive.md`; distill it as memory, do not raw-copy `PLAN.md`.
11. After the archive is written and validation is complete, delete only the current workspace root `PLAN.md`. Do not delete archived plans, fallback templates, or any nested `PLAN.md`. If archiving was skipped or failed, keep `PLAN.md` and report why.
12. Return files changed, validation, risks, archive path, deleted `PLAN.md` status, remaining risks, next action if any, and final status.

Rules:
- Do not rerun full planning.
- Do not create `REVIEW.md`.
