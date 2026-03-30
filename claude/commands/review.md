---
description: Review uncommitted changes, a branch diff, or a specific commit using the shared rubric
argument-hint: [uncommitted | branch <base> | commit <sha>]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Review

Use `~/.claude/review-rubric.md` as the source of truth for review output and priorities.

## Your task

1. Inspect `git status --short` and `git diff --stat` first.
2. Determine the target:
   - no args → review uncommitted changes if present, else review current branch against the default branch
   - `uncommitted` → review staged, unstaged, and relevant untracked changes
   - `branch <base>` → diff current branch against merge-base with `<base>`
   - `commit <sha>` → review `git show <sha>`
3. Read the shared rubric from `~/.claude/review-rubric.md`.
4. Read `./PLAN.md` when present and use it for plan-compliance review.
5. Review only the target scope.
6. Cover the full review stack from the rubric:
   - self-check
   - plan compliance
   - adversarial review
   - human checkpoint trigger when needed
7. Report concise findings with severity, file/line, why it matters, and the smallest fix.
8. If the diff conflicts with the plan, say so explicitly.
9. If a human should arbitrate risk, replan, or broad-impact tradeoffs, say so explicitly.
10. End with exactly one verdict: `GO`, `GO WITH NOTES`, or `BLOCK`.

If the target is ambiguous, ask only the narrowest blocking question.
