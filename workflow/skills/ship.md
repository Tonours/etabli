# Ship Contract

End-to-end delivery of one task: plan, adversary, implement, checks,
fresh-context review, commit, push, PR, CI green. Invoked explicitly only —
never ambiently routed. Invoking it is consent for the branch push and PR
creation it describes, per the human-checkpoint rules in `workflow/spec.md`.

## Required Sequence

1. Refuse to start from a dirty working tree unless the user names what to do
   with the existing changes.
2. Branch: if on the default branch, create `feat/<slug>` (or `fix/<slug>`)
   from it. Never commit to the default branch directly.
3. Run the full autonomous chain from
   `workflow/skills/implementation-loop.md`: understand, plan-loop, plan
   adversary, implement with tests, plan checks, simplification pass,
   fresh-context review, code-diff adversary, archive, root `PLAN.md`
   cleanup.
   During implementation, make a checkpoint commit on the ship branch after
   each coherent slice whose focused checks pass — never staging `PLAN*.md`.
   Checkpoints are revert points on a squash-mergeable branch, not release
   history.
4. Pre-commit pass: review the diff, sweep dead code, debug artifacts, and
   scope drift; run targeted tests for the touched code.
5. Final sweep commit with the project's commit style; never stage
   `PLAN*.md`.
6. Push the feature branch and open a PR. Write the body per
   `workflow/pr-body-contract.md`: English, the project's template intact,
   placeholders filled, checklists unchecked, no AI attribution. State the
   stack explicitly when the base is not the default branch.
7. CI: follow the `ci-fix` contract (existing attempt and time caps) until
   checks are green, blocked, or capped.
8. If reviewer or bot feedback already exists on the PR when CI settles,
   report it; treating it is a separate explicit request.
9. Report: branch, commits, PR URL, CI state, archive path, remaining risks.

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
and the fresh-context review verdict.
