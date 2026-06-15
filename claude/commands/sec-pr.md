---
description: Audit a Dependabot or security PR through gh CLI
argument-hint: [PR URL/number/repo]
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion]
---

# Sec PR

User request: $ARGUMENTS

Audit a security PR. Never trust the body alone. Cross-check against Dependabot,
GHSA, lockfile resolution, ignored/deferred evidence, and CI.

Default is read-only. Do not edit the PR body, approve, or merge unless the user
explicitly asked for post-validation actions and the verdict is `PASS`. Never merge automatically.

Phases:

1. Resolve repo and local clone.
2. Read PR metadata and diff with `gh pr view` and `gh pr diff`.
3. Parse body sections: Fixed, Ignored, Deferred, Resolutions added,
   Resolutions removed.
4. Fetch Dependabot alert and GHSA advisory for every Fixed and Ignored alert.
5. Create an isolated `git worktree` for lockfile verification.
6. Align Node and install in one shell when needed; judge install by exit code
   and populated `node_modules`.
7. Verify Fixed alerts: dependency/resolution >= patched, lock resolved >=
   patched, parent chain plausible, no vulnerable residual copy.
8. Verify removed resolutions are redundant.
9. Reproduce Ignored evidence.
10. Surface Deferred age relative to today.
11. Check CI.
12. Report `PASS`, `FAIL`, or `INVESTIGATE`.

If verdict is `PASS` and user confirms external writes, check PR body boxes and
approve. Print the PR URL for manual squash and merge. Never merge.
