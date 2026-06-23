Review staged and unstaged changes:

```bash
git status --short
git diff --stat
git log --oneline -5
```

Then:
1. Stage relevant changes with `git add` (be specific, avoid `git add -A`)
2. Write conventional commit message — subject line only, no body, no trailers,
   max 72 chars, lowercase, imperative:
   - feat(scope): new feature
   - fix(scope): bug fix
   - refactor(scope): code refactoring
   - test(scope): test changes
   - docs(scope): documentation
   - chore(scope): maintenance
3. Commit with the message
4. Push to current branch

Squash mode (when the request says "squash", "un seul commit", "1-2 commits max",
"tidy commits"):
- Soft-reset the branch's own commits and recommit as one (or two) clean commits,
  subject-only. Never touch commits already on the base branch.
- Push with `--force-with-lease`.
5. If no PR exists, create with `gh pr create`:
   - Title matches commit message
   - Body summarizes branch changes
   - Add relevant labels

Show PR URL when done.
