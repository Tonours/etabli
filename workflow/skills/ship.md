# Ship Contract

End-to-end delivery of one task: plan, adversary, implement, checks,
fresh-context review, commit, push, PR, CI green. Invoked explicitly only —
never ambiently routed. Invoking it is consent for the branch push and PR
creation it describes, per the human-checkpoint rules in `workflow/spec.md`.

## Required Sequence

1. Isolate the run per `workflow/skills/worktree-isolation.md`: confirm the base
   worktree is clean, then create one dedicated worktree and branch named per
   `workflow/git-contract.md` (`<type>/<ticket-id>-<short-slug>`, slug 3 words
   max, whole name under 50 characters) from the default branch, or from the named
   parent branch when the user asked to stack. Never commit to the default
   branch directly. Refuse to start from a dirty base worktree unless the user
   names what to do with the existing changes.
2. Run every phase below inside that worktree. The run's root `PLAN.md` lives
   there, which is what keeps concurrent ship runs from sharing one plan.
3. Run the full autonomous chain from
   `workflow/skills/implementation-loop.md`: understand, plan-loop, plan
   adversary, implement with tests, plan checks, simplification pass, quality
   pass, Logic+Spec lead review, code-diff adversary, archive, root
   `PLAN.md` cleanup.
   During implementation, make a checkpoint commit on the ship branch after
   each coherent slice whose focused checks pass — never staging `PLAN*.md`.
   Checkpoints are revert points on a squash-mergeable branch, not release
   history.
4. **Cumulative review gate:** before push, ensure a Logic+Spec lead review ran on
   `git diff <base>...HEAD` (merge-base with the PR base). Per-slice reviews do
   not satisfy this. Record `cumulative_review: <base>...HEAD @ <sha>`.
5. Pre-commit pass on the cumulative branch diff, which the loop's per-slice
   passes never saw as a whole: sweep debug artifacts, leftover checkpoint
   scaffolding, and scope drift across slices; run targeted tests for the
   touched code. Skip only when the branch holds a single slice, and say so.
6. Final sweep commit per `workflow/git-contract.md` (subject only, no body);
   never stage `PLAN*.md`.
7. Run the complete relevant `scripts/verify-agentic-infra` group on the final
   diff per `workflow/skills/implementation-loop.md`. A red group blocks the
   push.
8. Push the feature branch and open a PR. Write the body per
   `workflow/pr-body-contract.md`: English, the project's template intact,
   placeholders filled, checklists unchecked, no AI attribution. State the
   stack explicitly when the base is not the default branch. Publish the dense
   version, then run that contract's non-ASCII check against the live body.
   The draft is not the evidence, the published body is.
9. CI: follow the `ci-fix` contract (existing attempt and time caps) until
   checks are green, blocked, or capped.
10. After CI-driven commits that touch runtime code: **delta re-review**
    (Logic hunter on the new diff only). Record `delta_rereview: yes|no|n/a`.
11. If reviewer or bot feedback already exists on the PR when CI settles,
    report it; treating it is a separate explicit request. Defects found
    **after** an internal GO (Macroscope, colleague, CI, prod) must be recorded
    with `workflow/templates/escaped-defect.md` before the miss is treated as
    closed. **Update** the existing metrics row for this PR (`escaped_later`,
    `buckets`) — do not append a second row. If no row exists yet, create one.
    Metrics storage follows the stack rule in
    `workflow/self-improvement/review-metrics.md` (etabli / obvault / brain).
12. Remove the run's worktree, or report the path and why it was kept, per
    `workflow/skills/worktree-isolation.md`.
13. Report: branch, commits, PR URL, CI state, archive path, worktree cleanup
    status, `cumulative_review`, `delta_rereview`, `reviewer_model`,
    `adversary_model` (or `same-family-pass: double-sample`),
    `deciding_code: complete|incomplete|n/a`, `escaped_defects_recorded: 0|<n>`,
    remaining risks. When the branch carries checkpoint commits, say the branch
    is squash-merge-only so its checkpoints never become history.
14. **Metrics row (one per PR):** if no row exists yet for this PR, append one
    (verdict + models + deciding_code; `escaped_later` starts at 0). If a row
    already exists (e.g. from an earlier escape update), leave it — do not
    duplicate. Storage: see `workflow/self-improvement/review-metrics.md`.

## Test Evidence

An empty grep is not a pass. Many runners (Jest among them) print their summary
on stderr, so a filtered pipeline can return nothing while the suite failed.
Trust the **exit code**, and quote the summary line the run actually printed.
Capture output to a file when running several packages in a loop, then read the
summaries back:

```bash
for p in a b c; do
  <runner> "$p" > "$LOG/$p.log" 2>&1
  echo "$p exit=$?"
done
grep -E '^Tests:|^Test Suites:' "$LOG"/*.log
```

When a suite fails, establish whether it is **yours** before reporting or fixing
it. Stash the diff, reinstall if dependencies moved, re-run the same suite on the
untouched base, and compare. A failure that reproduces identically on the base is
pre-existing: say so with the evidence, list it under the PR's known limitations,
and do not fix it in this branch. A failure that disappears on the base is yours.

Re-run once before calling a single failure a flake, and name the mechanism
(port race, timeout, shared fixture). "Flaky" without a mechanism is a guess.

## Hard Limits

- Never merge the PR.
- Never force-push.
- Never push to the default branch from `/ship`. Direct default-branch
  integration is outside `/ship` and requires a separate current user request
  satisfying `workflow/git-contract.md`.
- All `workflow/spec.md` autonomous-loop rules apply: mandatory event ledger,
  no-progress stop, check-freeze, explicit cap, fresh-context review.
- Code-diff adversary: cross-model or documented double-sample only; single
  same-family pass blocks the ship (full autonomy).
- Any stop from the implementation loop (CHALLENGED, blocker, no validation
  surface, human checkpoint outside this contract's consented writes) stops
  the whole ship run with a `blocked` event and a handoff.

## Completion Evidence

A ship run is complete only when the final report names: PR URL, green CI (or
capped/blocked state), implemented-plan archive path, event ledger location,
the fresh-context review verdict, `cumulative_review`, `adversary_model` (or
double-sample), `deciding_code`, `escaped_defects_recorded`, and the worktree
cleanup status.
