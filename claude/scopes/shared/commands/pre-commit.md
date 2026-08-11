---
description: Final pass before committing - review, sweep debug artifacts, targeted tests, commit message
argument-hint: [optional scope note]
allowed-tools: [Read, Glob, Grep, Bash, Edit, AskUserQuestion]
---

# Pre-Commit

User request: $ARGUMENTS

Final quality pass over the working tree before the user commits. Small fixes
are applied directly; findings that change behavior are reported, not fixed.

## Steps

1. Inspect `git status --short` and `git diff` (staged and unstaged).
2. Review the diff for correctness, regressions, and safety using
   `workflow/review-rubric.md` when available.
3. Sweep the diff — apply these fixes directly:
   - dead code introduced by the change (unused vars, unreachable branches,
     leftover exports);
   - debug artifacts: `console.log`, commented-out code, stray TODOs;
   - comments that restate the code (keep mandatory tooling directives);
   - hardcoded values that the surrounding code passes as parameters or config.
4. Check convention conformity against neighboring files: naming, imports,
   test selectors (`data-test-*` where the codebase uses them).
5. Verify no `PLAN.md` / `PLAN-*.md` is staged; unstage it if found.
6. Run the narrowest test command covering the changed behavior and the
   project's typecheck/lint if configured. Report exact commands and output.
7. Report findings by severity, then propose the commit message per
   `workflow/git-contract.md`: subject only, max 72 chars, lowercase,
   imperative, no body or trailers.

## Rules

- Do not commit. The user commits.
- Do not widen scope: only the current diff and its immediate blast radius.
- If tests fail, that is the headline of the report, not a footnote.

End with:

```text
Pre-commit: <clean | n findings fixed, n reported> | tests: <state>
suggested: <type>(<scope>): <subject>
```
