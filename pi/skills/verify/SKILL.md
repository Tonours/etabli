---
name: verify
description: Run all verification checks before committing changes
---

# Verify

Verify changes work correctly. This is the most important step.

1. Check state: `git status --short` and `git diff --stat`
2. **Type check**: `bun run typecheck` or `tsc --noEmit` or `npx tsc --noEmit`
3. **Tests**: `bun test` or `npm test` (relevant files only, not full suite)
4. **Lint**: `bun run lint` or `npm run lint`
5. **Build**: `bun run build` or `npm run build` (if applicable)

For each check:
- Run the command
- Report pass/fail
- If failed, diagnose and fix if obvious
- If not obvious, explain the issue

Summary at end: all checks passed / issues found.
