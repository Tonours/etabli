---
description: Create one scoped conventional commit from the current worktree; never push or open a PR
argument-hint: [optional scope or intent]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Commit

User request: $ARGUMENTS

Create one reviewable commit and stop.

## Procedure

1. Inspect `git status --short`, staged and unstaged diffs, and
   `git log --oneline -5`. Preserve unrelated user changes.
2. Identify the files that belong to the requested change. If ownership is
   ambiguous, ask one narrow question before staging.
3. Run the narrowest relevant validation that has not already passed on the
   final diff. A failing required check blocks the commit.
4. Stage exact paths with `git add -- <paths>`; never use `git add -A` or `git add .`.
5. Verify no root `PLAN.md` or `PLAN*.md` is staged.
6. Commit with one English conventional-commit subject, no body or trailers:
   `feat|fix|refactor|test|docs|chore(scope): description`. Keep it lowercase,
   imperative, and under about 72 characters.
7. Show the new commit subject and final `git status --short`.

## Boundaries

- Do not push, create a PR, merge, amend, squash, rebase, or rewrite history.
- Do not stage unrelated files or discard working-tree changes.
- Do not add AI attribution.
- If there is nothing relevant to commit, stop without creating an empty commit.
