---
name: implement
description: Implement an existing READY PLAN.md
---

# Implement

Follow `workflow/spec.md`.

## Source resolution

Before saying a workflow source is missing, resolve sources in this order:

1. Prefer the current workspace copies:
   - `workflow/spec.md`
   - `workflow/plan-archive.md`
2. If one of those files is missing in the current workspace, fall back to the Pi agent shared copies when this skill is loaded through `~/.pi/agent/skills`:
   - `../../workflow/spec.md`
   - `../../workflow/plan-archive.md`
3. If those are unavailable, fall back to the Etabli repo copies when this skill is loaded from the repo target path:
   - `../../../workflow/spec.md`
   - `../../../workflow/plan-archive.md`
4. If any fallback files exist, read them and continue. Do not tell the user the workflow spec is missing.
5. If archive instructions are missing after all lookups, still implement only from `READY`; skip archiving with a warning instead of inventing an archive format.

1. Inspect repo state.
2. Read `PLAN.md`.
3. Stop if missing, `DRAFT`, or `CHALLENGED`.
4. Implement `READY` plan steps in order.
5. Keep changes minimal and scope-bound.
6. Update `PLAN.md` only for progress or newly discovered facts.
7. Run focused checks.
8. If implementation and checks completed, archive the final plan in `docs/plan/YYYYMMDD-short-slug.md` using `workflow/plan-archive.md`; distill it as memory, do not raw-copy `PLAN.md`.
9. Return files changed, validation, risks, archive path, and final status.

Rules:
- Do not rerun full planning.
- Do not create `REVIEW.md`.
