---
name: review
description: Review diffs for bugs, regressions, plan drift, and conventions.
---

# Review

Read and follow the shared contract in `workflow/skills/review.md` and the
rubric in `workflow/review-rubric.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Procedure

1. **Break-first** — do not open `PLAN.md`; fill lens + deciding-code tables.
2. **Plan-fit** — if `PLAN.md` is in play, open it only after pass 1.
3. Load `code-quality` when exposed. Otherwise use the narrowest exposed domain
   skill or the shared contract's local-sibling fallback.

## Rules

- Stay read-only unless the user explicitly asks for validation beyond review.
- `GO` forbidden if a runtime deciding-code row is empty or `not run`.
- End with `Verdict: GO`, `Verdict: GO WITH NOTES`, or `Verdict: BLOCK`.
