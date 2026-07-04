# CI Fix Contract

Shared contract for autonomous GitHub PR CI repair across AI harnesses.

Runtime adapters may add tool syntax or source-resolution details. They must not
weaken the explicit-invocation requirement, stash/restore rule, force-push
guard, attempt cap, or anti-test-disarming rules.

## Purpose

Drive an autonomous loop that gets a PR's CI green. This contract can authorize
stash, checkout, rebase, commit, and push only when explicitly invoked or when
the user clearly asks to fix CI until green.

If the user asked only to inspect, diagnose, review, or explain CI, do not use
this contract.

## Preflight

1. Run `git status --porcelain`.
2. If dirty, stash with `git stash push -u -m ci-fix-autostash`.
3. Always restore the stash before returning on success, abort, or block. If
   `git stash pop` conflicts, report it and overwrite nothing.
4. Record start time. Stop after about 45 minutes, including wait time.
5. Verify `gh auth status`.

## Target

- With PR number: `gh pr view <num> --json headRefName,number,url,baseRefName,title,headRefOid`.
- Without PR number: use the current branch PR.
- Fetch and checkout the PR branch.
- Track owner, repo, number, branch, base, and SHA.

Stop if no PR exists, `gh` is unavailable, auth is missing, or the target branch
cannot be identified.

## Green Definition

All non-ignored check runs and commit statuses are `success`, `skipped`, or
`neutral`.

Ignored checks: names containing `qlty`, `macroscope`, or `correctness`
case-insensitively.

Queued, in-progress, and pending are not green and not failed.

## Loop

Run until CI green, 5 fix attempts used, or time cap:

1. Poll fresh SHA:
   - `gh pr view <num> --json headRefOid`
   - `gh api repos/<owner>/<repo>/commits/<sha>/check-runs`
   - `gh api repos/<owner>/<repo>/commits/<sha>/status`
2. Classify non-ignored checks as running, green, or failed.
3. If anything is running, wait 60-120 seconds and re-poll.
4. If all green, restore stash and report success.
5. If failed and none running, increment attempt and fix.
6. If SHA moved from someone else's push, re-poll on the new SHA.

## Fix Mode

1. Fetch base.
2. If branch is behind, rebase on `origin/<base>`.
3. On non-trivial conflict, abort rebase, restore stash, and stop.
4. If rebase succeeds, push with `--force-with-lease`, never plain `--force`.
5. For each failed check, diagnose root cause from `gh run view --log-failed`
   or the check details URL.
6. Reproduce locally when possible before editing.
7. Fix root cause only. No opportunistic refactor.
8. Re-run the focused local check.
9. Commit with `chore(ci): fix <short cause>`.
10. Before every push, verify `git branch --show-current` matches the PR branch.
11. Push. If rejected, pull/rebase and retry only if conflict-free.

## Hard Rules

- Never make a test pass by disarming it: no `.skip`, `.only`, `xfail`,
  deleting tests, weakening assertions, fake mocks, or timeout inflation.
- Do not regenerate snapshots or fixtures unless the diff exactly matches a
  deliberate PR behavior change and that is explained.
- Editing a test is allowed only when the test is factually wrong for the
  intended behavior.
- Infra, missing secret, dead runner, flaky external service, or deploy failures
  are blockers, not code fixes.
- Max 5 code-fix attempts.
- Never plain `--force`.
- Always restore the stash.

## Output

```md
CI state: green | blocked | gave up | time cap | conflict
PR:
Fixes:
- check -> cause -> commit
Validation:
- command -> result
Manual follow-up:
Stash state:
```
