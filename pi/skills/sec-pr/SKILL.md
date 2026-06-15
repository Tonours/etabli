---
name: sec-pr
description: Audit a Dependabot or security GitHub PR with gh CLI. Verifies fixed alerts against Dependabot/GHSA, lockfile resolution, ignored/deferred evidence, CI, and returns PASS/FAIL/INVESTIGATE. Use for security PR review, Dependabot validation, vulnerability PR audit, or /sec-pr.
---

# Sec PR

Audit a security PR. Never trust the PR body alone. Cross-check each claim
against independent sources and the resolved lockfile.

Default is read-only. Do not edit the PR body, approve, or merge unless the user
explicitly asked for post-validation actions and the verdict is `PASS`.
Never merge automatically.

## Input

Accept `<PR_ID>`, `<PR_ID> <owner/repo>`, `owner/repo#123`, or a PR URL. If the
repository cannot be inferred, ask one blocking question.

## Preconditions

- `gh auth status` must pass.
- The token must access Dependabot alerts.
- A local clone of the repo must exist for isolated worktree verification.
- Package manager must be available: yarn, npm, or pnpm.

Stop with `GITHUB_CLI_UNAVAILABLE`, `GITHUB_AUTH_REQUIRED`, or
`LOCAL_CLONE_REQUIRED` when blocked.

## Phases

1. Target:
   - resolve repo and clone path from cwd, `~/work/<repo-name>`, or user input
   - read PR metadata and diff with `gh pr view` and `gh pr diff`
   - parse body sections: Fixed, Ignored, Deferred, Resolutions added,
     Resolutions removed
2. Independent truth:
   - for every Fixed and Ignored alert, fetch Dependabot alert:
     `gh api repos/$REPO/dependabot/alerts/<N>`
   - fetch GHSA advisory:
     `gh api advisories/<GHSA_ID>`
   - patched version of reference is Dependabot `first_patched_version`; compare
     with GHSA and flag divergences
   - `state: open` before merge is normal
3. Isolated worktree:
   - create a dedicated `git worktree`, never mutate the active clone
   - detect package manager and lockfile
   - align Node in the same shell as install when `.nvmrc` or engines require it
   - judge install success by exit code and populated `node_modules`, not by the
     word `error` in logs
   - if install truly fails, use static lockfile verification and mark that fact
   - always remove the worktree and temp marker on exit
4. Fixed:
   - confirm package.json dependency or resolution is >= patched
   - confirm lockfile resolved version is >= patched
   - confirm scoped parent chain is plausible
   - confirm no vulnerable residual version remains
5. Resolutions removed:
   - confirm the lockfile now resolves naturally to a safe version without the
     removed pin
6. Ignored:
   - reproduce the justification from code/advisory evidence; do not trust body
     prose
7. Deferred:
   - fetch alert creation dates and compute age relative to today; flag stale
     deferred alerts over 7 days as vigilance, not automatic failure
8. CI:
   - read `statusCheckRollup`
   - relevant failures or pending checks block `PASS`
9. Report:
   - return `PASS`, `FAIL`, or `INVESTIGATE`

## Output

```md
## Security PR #<ID> - <title>

### CI

### Fixed
| Alert | Package | Patched | PR action | Lock resolved | Parent chain | Verdict |
|---|---|---|---|---|---|---|

### Resolutions Added

### Resolutions Removed

### Ignored

### Deferred

### Verdict: PASS | FAIL | INVESTIGATE
```

## Post-Validation Actions

Only if verdict is `PASS` and the user explicitly confirms external writes:

1. Check PR body boxes with `gh pr edit --body-file -`.
2. Approve with `gh pr review --approve`.
3. Print the PR URL for manual squash and merge.

Rules:

- Never merge.
- Never use `--ignore-engines`.
- Never mutate the active clone for lock verification.
- Clean up worktrees even on error.
- If evidence is missing or divergent, use `INVESTIGATE`, not `PASS`.
