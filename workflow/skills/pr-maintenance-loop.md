# PR Maintenance Loop Contract

Shared contract for a supervised single-PR maintenance loop.

Runtime adapters may add command syntax, GitHub snapshot collection, or UI
details. They must not change the isolation rule, latest-head evidence rule,
fresh-context review requirement, or human-controlled external write boundary.

## Purpose

Move one pull request through an implementation, review, cleanup, and reporting
loop without mixing branches or trusting stale review evidence.

This is a pilot contract for one PR at a time. It is not a multi-PR overnight
orchestration contract.

## Preconditions

1. Resolve exactly one PR target.
2. Apply the preconditions in `workflow/skills/worktree-isolation.md`, then
   create or select one isolated worktree, branch, and thread for this PR.
3. Record the PR URL, branch, worktree path, base SHA, latest pushed head SHA,
   and planned validation commands.

## Isolation Rules

Follow `workflow/skills/worktree-isolation.md`. One PR, one worktree, one loop.
Additionally, do not mix fixes for several PRs in the same branch or thread.

## Loop Phases

1. Inspect the PR state, branch, latest head, diff, comments, checks, and
   relevant files.
2. Implement the smallest defensible fix in the PR worktree only.
3. Run the relevant tests and checks.
4. Run a fresh-context review on the current diff. The reviewer must not be the
   implementation context.
5. Fix actionable review findings in the same PR worktree.
6. Run a cleanup/refactor pass for duplication, messy abstractions, dead code,
   or avoidable complexity introduced by the loop.
7. Run another fresh-context review after cleanup when the diff changed.
8. Classify review and check evidence against the latest pushed head SHA.
9. Stop only when the latest pushed head is clean, or report a blocked state
   with attempts, evidence, uncertainty, and needed input.
10. Produce a final report.

## Latest-Head Evidence Rule

Never trust a clean review or green check unless it applies to the latest pushed
head SHA.

Use `scripts/pr-latest-head-status` or an adapter with equivalent semantics to
classify the current snapshot:

- `clean_latest_head`: latest head has clean review evidence and latest-head
  checks are green.
- `stale_review`: clean review evidence exists only for an older head.
- `needs_rerun`: latest head has actionable findings, failing/pending/missing
  checks, missing review evidence, or missing latest-head metadata.

An old clean review must never count as done after a new push.

## External Write Boundary

Default mode is supervised and local.

- Do not push.
- Do not merge.
- Do not deploy.
- Do not post PR comments.
- Do not request a bot review.
- Do not update external systems.

External write-back is allowed only when the user explicitly asks for that
specific action and the active command contract authorizes it.

## Final Report

Close the loop with:

- PR link and number.
- Branch and worktree.
- Latest pushed head SHA used for evidence.
- What was fixed.
- Files changed.
- Tests and checks run.
- Fresh-context review result.
- Latest-head status: `clean_latest_head`, `stale_review`, or `needs_rerun`.
- Worktree cleanup status.
- Remaining risks, blockers, or next input needed.

## Stop Conditions

Stop as done only on `clean_latest_head` plus passing planned validation.

Stop as blocked when:

- the same check fails three times with no new evidence;
- no fresh-context reviewer is available for an autonomous run;
- the latest head cannot be identified;
- required checks cannot be run or mapped to the latest head;
- fixing the PR requires touching another PR, branch, sibling worktree,
  production system, secret, deploy, merge, or external write-back outside the
  user's explicit consent.
