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
   `workflow/skills/implementation-loop.md`: plan-loop, adversary, implement,
   plan checks, fresh-context review, archive, root `PLAN.md` cleanup.
4. Pre-commit pass: review the diff, sweep dead code, debug artifacts, and
   scope drift; run targeted tests for the touched code.
5. Commit with the project's commit style. One commit per coherent unit;
   never stage `PLAN*.md`.
6. Push the feature branch and open a PR using the project's PR template.
   Fill placeholders; leave checklists unchecked; no AI attribution.
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
