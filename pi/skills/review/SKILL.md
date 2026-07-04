---
name: review
description: Review changes for correctness, regressions, risks, and plan drift
---

# Review

Read and follow the shared contract in `workflow/skills/review.md`.

## Source resolution

Resolve the shared contract before acting:

1. Prefer the current workspace copy: `workflow/skills/review.md`.
2. If missing, fall back to the Pi agent shared copy:
   `../../workflow/skills/review.md`.
3. If unavailable, fall back to the Etabli repo copy when loaded from the repo
   target path: `../../../workflow/skills/review.md`.
4. If no copy exists, stop with
   `SHARED_CONTRACT_MISSING: workflow/skills/review.md`.

Rules:
- Use `workflow/review-rubric.md` when available.
- Stay read-only unless the user explicitly asks for validation beyond review.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
