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
7. Report concise findings grounded in the reviewed diff with severity, file/line, why it matters, the smallest fix, and `review_comment:` text suitable for an inline review thread.
8. If the diff conflicts with the plan, say so explicitly.
9. Verify every reported line or range exists in the supplied diff; if there are no actionable issues, write exactly `No findings.`
10. If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so explicitly.
11. End with exactly one verdict: `GO`, `GO WITH NOTES`, or `BLOCK`.

If the target is ambiguous, ask only the narrowest blocking question.
