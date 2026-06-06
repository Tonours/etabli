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
5. Use bounded read-only inspection of nearby code, tests, config, or docs only when it materially confirms or rejects a suspected finding.
6. Do not edit files, install dependencies, or run broad/slow validation unless the user explicitly asked for that level of review.
7. Report only actionable findings grounded in the reviewed diff. Verify every reported line or range exists in that diff.
8. Include severity, location, impact, smallest fix, and `review_comment:` with one concise inline-ready comment for each finding.
9. If there is no actionable issue, put exactly `No findings.` as the only finding, then still include the final verdict.
10. Escalate human checkpoint only for real tradeoffs or accepted risk.
11. End with exactly one verdict: `GO`, `GO WITH NOTES`, or `BLOCK`.

Rules:
- No style nitpicks unless they affect correctness or maintenance.
- Prefer minimal fixes.
