---
name: review
description: Review changes for correctness, regressions, risks, plan drift, and convention fit. Break-first then plan-fit; mandatory deciding-code table.
---

# Review

Read and follow the shared contract in `workflow/skills/review.md` and the
rubric in `workflow/review-rubric.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/review.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/review.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/review.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/review.md`.

## Procedure

1. **Break-first** — do not open `PLAN.md`; fill lens + deciding-code tables.
2. **Plan-fit** — if `PLAN.md` is in play, open it only after pass 1.
3. Load `suite-router` / `code-quality` when the surface needs domain practice.

## Rules

- Stay read-only unless the user explicitly asks for validation beyond review.
- `GO` forbidden if a runtime deciding-code row is empty or `not run`.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
