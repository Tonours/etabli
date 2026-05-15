---
name: review
description: Review changes for correctness, regressions, risks, and plan drift
---

# Review

Use `workflow/review-rubric.md`.

1. Inspect `git status --short` and `git diff --stat`.
2. Determine target scope from the user request.
3. Read `PLAN.md` when present.
4. Review correctness, regressions, safety, validation, maintainability, and plan drift.
5. Report only actionable findings with severity, location, impact, and smallest fix.
6. Escalate human checkpoint only for real tradeoffs or accepted risk.
7. End with exactly one verdict: `GO`, `GO WITH NOTES`, or `BLOCK`.

Rules:
- No style nitpicks unless they affect correctness or maintenance.
- Prefer minimal fixes.
