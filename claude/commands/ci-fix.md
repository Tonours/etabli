---
description: Autonomously fix failing GitHub PR CI through gh CLI
argument-hint: [PR number, optional; defaults to current branch]
allowed-tools: [Read, Glob, Grep, Bash, Edit, MultiEdit, Write, AskUserQuestion, Task]
---

# CI Fix

User request: $ARGUMENTS

Use only when the user explicitly asks to fix CI until green. This command may
stash, checkout, rebase, commit, and push.

Preflight:

1. `git status --porcelain`.
2. If dirty, `git stash push -u -m ci-fix-autostash`.
3. Always restore the stash before returning.
4. Stop after about 45 minutes.
5. Verify `gh auth status`.

Loop:

1. Resolve PR from argument or current branch.
2. Poll fresh SHA, check-runs, and statuses through `gh`.
3. Ignore checks containing `qlty`, `macroscope`, or `correctness`.
4. Wait while any non-ignored check is queued, in-progress, or pending.
5. Fix failed checks only after none are running.
6. Max 5 code-fix attempts.
7. Rebase on base only when needed; push with `--force-with-lease`, never plain
   `--force`.
8. Diagnose from CI logs, reproduce locally when possible, fix root cause only,
   verify, commit, push, and re-poll.

Hard rules:

- Never disarm tests.
- Do not weaken assertions or inflate timeouts to mask failure.
- Do not regenerate snapshots unless the diff exactly matches intended behavior.
- Infra, secrets, runner, flaky external, and deploy failures are blockers.
- Check branch before every push.
- Always restore stash.
