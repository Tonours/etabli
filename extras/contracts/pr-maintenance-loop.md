# PR Maintenance Loop Contract

Shared contract for a supervised PR maintenance loop and read-only stacked-PR
frontier projection.

Runtime adapters may add command syntax, GitHub snapshot collection, or UI
details. They must not change the isolation rule, latest-head evidence rule,
fresh-context review requirement, or human-controlled external write boundary.

## Purpose

Move one pull request through an implementation, review, cleanup, and reporting
loop without mixing branches or trusting stale review evidence. For an ordered
stack, calculate how far latest-head evidence remains continuously valid from
the root; this projection does not execute maintenance across several PRs.

Implementation remains one PR at a time. Stack mode is a provider-neutral,
read-only evidence projection, not a multi-PR overnight orchestration contract.

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

When a provider rewrites a head without changing the diff, a clean review may
bind by an explicit matching patch identity. Checks still must bind to the exact
latest head. Patch identity never overrides current actionable findings.

## Ordered Stack Frontier

An optional snapshot may provide `prs` in root-to-tip order. Every entry must
have a unique PR number and head ref, and each entry after the root must identify
the preceding PR by `parent_number` or use its head ref as `base_ref`.

`scripts/pr-latest-head-status` then returns:

- `clean_contiguous_run` when every PR has applicable clean review evidence and
  exact-latest-head green checks;
- `partial_contiguous_run` when a clean root run stops at a later gap;
- `blocked_at_root` when the root itself is not clean;
- `invalid_snapshot` when ordering, identity, or adjacency is ambiguous.

Only PRs in `verified_run` are marked `landable`. `ceiling_pr` is the last PR in
that run and `next_gap` is the first PR that needs attention. These fields are
evidence only: they do not authorize push, comment, merge, or provider writes.

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
- Latest-head status: `clean_latest_head`, `stale_review`, or `needs_rerun`; for
  a stack, include the contiguous status, `verified_run`, `ceiling_pr`, and
  `next_gap`.
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
