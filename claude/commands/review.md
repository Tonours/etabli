---
description: Review uncommitted changes, a branch diff, or a specific commit using the shared rubric
argument-hint: [uncommitted | branch <base> | commit <sha>]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Review

Use `workflow/review-rubric.md` as the source of truth for review output and priorities when it exists. Fall back to `~/.claude/review-rubric.md` only outside a harnessed project.

## Your task

1. Inspect `git status --short` and `git diff --stat` first.
2. Determine the target:
   - no args → review uncommitted changes if present, else review current branch against the default branch
   - `uncommitted` → review staged, unstaged, and relevant untracked changes
   - `branch <base>` → diff current branch against merge-base with `<base>`
   - `commit <sha>` → review `git show <sha>`
3. Read the shared rubric from `workflow/review-rubric.md`, or `~/.claude/review-rubric.md` if the project copy is unavailable.
4. Read `./PLAN.md` when present and use it for plan-compliance review.
5. Review only the target scope.
6. Cover the full review stack from the rubric:
   - self-check
   - plan compliance
   - adversarial review
   - human checkpoint trigger when needed
7. Use bounded read-only inspection of nearby code, tests, config, or docs only when it materially confirms or rejects a suspected finding.
8. Do not edit files, install dependencies, or run broad/slow validation unless the user explicitly asked for that level of review.
9. Report concise findings grounded in the reviewed diff using stable labels: `severity:`, `file:`, `line:` or `line_range:`, `issue:`, `impact:`, `review_comment:`, and `suggested_fix:`.
10. Use `line_range:` instead of `line:` when the inline comment spans multiple changed lines.
11. Keep `review_comment:` as one inline-ready GitHub-style review thread comment without code fences or tables.
12. If the diff conflicts with the plan, say so explicitly.
13. Verify every reported line or range exists in the supplied diff; if there are no actionable issues, put exactly `No findings.` as the only finding, then still include the final verdict.
14. If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so explicitly.
15. End with exactly one verdict: `GO`, `GO WITH NOTES`, or `BLOCK`.

If the target is ambiguous, ask only the narrowest blocking question.
