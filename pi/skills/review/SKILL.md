---
name: review
description: Review proposed changes before commit and flag correctness, risks, and missing edge cases
---

# Review

Run a production-minded code review with concise decisions.

1. Read the shared review rubric from the first existing file in this order:
   - `./claude/review-rubric.md`
   - `../../claude/review-rubric.md`
2. Inspect `git status --short`, `git diff --stat` and full diff for context.
3. Look for:
   - ✅ correctness bugs (logic, edge cases, error paths)
   - 🧨 regressions (behavior changes, API compatibility)
   - 🛡️ security/safety issues (secrets, filesystem access, injection, permissions)
   - 🧪 missing or weak validation/tests
   - 📦 maintainability (readability, complexity, dead code)
4. Verify changed files match the plan and scope.
5. For each issue, provide:
   - severity: `high | medium | low`
   - precise file/line (or block)
   - concrete fix suggestion
6. End with one-line verdict:
   - `GO` / `GO WITH NOTES` / `BLOCK`
7. If anything is clearly broken, recommend rollback strategy.
8. If the user wants target-scoped review for uncommitted changes / a branch / a commit, use `/review`.

Rules:
- Be direct and specific.
- Prefer minimal fixes.
- Flag assumptions.
- No style nitpicking unless it impacts correctness or maintenance.
