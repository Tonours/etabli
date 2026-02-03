Verify the changes work correctly. This is the most important step.

Current state:

```bash
git status --short
git diff --stat
```

Run these checks:

1. **Type check**: `bun run typecheck` or `tsc --noEmit` or `npx tsc --noEmit`
2. **Tests**: `bun test` or `npm test` (relevant files only, not full suite)
3. **Lint**: `bun run lint` or `npm run lint`
4. **Build**: `bun run build` or `npm run build` (if applicable)

For each check:

- Run the command
- Report pass/fail status
- If failed, diagnose and fix if obvious
- If not obvious, explain the issue

If UI changes:

- Describe manual verification steps needed
- List visual elements to check

Summary at end: all checks passed / issues found
