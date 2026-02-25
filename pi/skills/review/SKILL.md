---
name: review
description: Review proposed changes before commit and flag correctness, risks, and missing edge cases
---

# Review

Run a production-minded code review with concise decisions.

1. Inspect `git status --short`, `git diff --stat` and full diff for context.
2. Look for:
   - ✅ correctness bugs (logic, edge cases, error paths)
   - 🧨 regressions (behavior changes, API compatibility)
   - 🛡️ security/safety issues (secrets, filesystem access, injection, permissions)
   - 🧪 missing or weak validation/tests
   - 📦 maintainability (readability, complexity, dead code)
3. Verify changed files match the plan and scope.
4. For each issue, provide:
   - severity: `high | medium | low`
   - precise file/line (or block)
   - concrete fix suggestion
5. End with one-line verdict:
   - `GO` / `GO WITH NOTES` / `BLOCK`
6. If anything is clearly broken, recommend rollback strategy.

Rules:
- Be direct and specific.
- Prefer minimal fixes.
- Flag assumptions.
- No style nitpicking unless it impacts correctness or maintenance.
