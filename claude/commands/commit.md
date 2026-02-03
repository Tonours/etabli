Review staged and unstaged changes:

```bash
git status --short
git diff --stat
git log --oneline -5
```

Then:

1. Stage relevant changes with `git add` (be specific, avoid `git add -A`)
2. Write conventional commit message:
   - feat(scope): new feature
   - fix(scope): bug fix
   - refactor(scope): code refactoring
   - test(scope): test changes
   - docs(scope): documentation
   - chore(scope): maintenance
3. Commit with the message
4. Push to current branch
5. If no PR exists, create with `gh pr create`:
   - Title matches commit message
   - Body summarizes branch changes
   - Add relevant labels

Show PR URL when done.
