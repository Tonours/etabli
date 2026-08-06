# Ship Contract

End-to-end delivery of one task: plan, adversary, implement, checks,
fresh-context review, commit, push, PR, CI green. Invoked explicitly only —
never ambiently routed. Invoking it is consent for the branch push and PR
creation it describes, per the human-checkpoint rules in `workflow/spec.md`.

## Required Sequence

1. Isolate the run per `workflow/skills/worktree-isolation.md`: confirm the base
   worktree is clean, then create one dedicated worktree and branch
   `feat/<slug>` (or `fix/<slug>`) from the default branch, or from the named
   parent branch when the user asked to stack. Never commit to the default
   branch directly. Refuse to start from a dirty base worktree unless the user
   names what to do with the existing changes.
2. Run every phase below inside that worktree. The run's root `PLAN.md` lives
   there, which is what keeps concurrent ship runs from sharing one plan.
3. Run the full autonomous chain from
   `workflow/skills/implementation-loop.md`: understand, plan-loop, plan
   adversary, implement with tests, plan checks, simplification pass,
   fresh-context review, code-diff adversary, archive, root `PLAN.md`
   cleanup.
   During implementation, make a checkpoint commit on the ship branch after
   each coherent slice whose focused checks pass — never staging `PLAN*.md`.
   Checkpoints are revert points on a squash-mergeable branch, not release
   history.
4. Pre-commit pass on the cumulative branch diff, which the loop's per-slice
   passes never saw as a whole: sweep debug artifacts, leftover checkpoint
   scaffolding, and scope drift across slices; run targeted tests for the
   touched code. Skip only when the branch holds a single slice, and say so.
5. Final sweep commit with the project's commit style; never stage
   `PLAN*.md`.
6. Run the complete relevant `scripts/verify-agentic-infra` group on the final
   diff per `workflow/skills/implementation-loop.md`. A red group blocks the
   push.
7. Push the feature branch and open a PR. Write the body per
   `workflow/pr-body-contract.md`: English, the project's template intact,
   placeholders filled, checklists unchecked, no AI attribution. State the
   stack explicitly when the base is not the default branch.
8. CI: follow the `ci-fix` contract (existing attempt and time caps) until
   checks are green, blocked, or capped.
9. If reviewer or bot feedback already exists on the PR when CI settles,
   report it; treating it is a separate explicit request.
10. Remove the run's worktree, or report the path and why it was kept, per
    `workflow/skills/worktree-isolation.md`.
11. Report: branch, commits, PR URL, CI state, archive path, worktree cleanup
    status, remaining risks. When the branch carries checkpoint commits, say
    the branch is squash-merge-only so its checkpoints never become history.

## Hard Limits

- Never merge the PR.
- Never force-push.
- Never push to the default branch.
- All `workflow/spec.md` autonomous-loop rules apply: mandatory event ledger,
  no-progress stop, check-freeze, explicit cap, fresh-context review.
- Any stop from the implementation loop (CHALLENGED, blocker, no validation
  surface, human checkpoint outside this contract's consented writes) stops
  the whole ship run with a `blocked` event and a handoff.

## Completion Evidence

A ship run is complete only when the final report names: PR URL, green CI (or
capped/blocked state), implemented-plan archive path, event ledger location,
the fresh-context review verdict, and the worktree cleanup status.
