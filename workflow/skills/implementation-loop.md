# Implementation Loop Contract

Shared implementation contract; adapters supply harness syntax. Select the route
in `workflow/spec.md` before the risk tier. Plan routes and high-risk work use
the full sequence. A bounded runtime fix remains ordinary coding unless a plan
is requested; an existing DRAFT/CHALLENGED plan blocks implementation.

## Risk tiers

Record `tier: small|standard|high-risk` before step 1; upgrade when needed,
never downgrade mid-run.

- **small** — docs-only, config-only, or a bounded single-surface edit with no
  runtime behavior change. Runs **outside the plan gate**: scoped recon
  (step 0), implement (step 8 semantics), product-flow check (step 11) when
  its trigger fires, checks (12), simplify (12b), quality (12c), report (17). One
  self-review of the cumulative diff replaces hunters and adversary passes
  (accepted risk: no external feedback; small excludes behavior change).
  No plan file and no READY gate unless the surface is contractual — in which
  case the tier is not small.
- **standard** (default) — runtime code change on a known surface. Full
  sequence below, except step 13b accepts a documented same-family
  double-sample instead of cross-model.
- **high-risk** — kernel guards, installer/deploy scripts, security, multi-surface contract changes, or a third
  recurrence of the same failure. Full sequence, cross-model adversary
  mandatory (13b), both hunters mandatory (13).

## Standing rules

`workflow/spec.md` § Rules governs every step and wins on conflict.

- No-progress stop and check-freeze as in `workflow/agent-quick-card.md`
  (always loaded); a no-progress stop lists the eliminated hypotheses.
- Before a mutable local-device or server action, name the exact target, the
  control path, and the post-check.
- A new transverse invariant ships with a mechanical check whose failure
  message names its remediation; the third occurrence of the same review
  finding becomes a mechanical check; instruction files stay maps, not manuals.
- In autonomous runs a session handoff is a `handoff` event (branch, sha, done,
  pending, next action, do-not-redo); a started migration is finished or handed
  off that way, never left half done.

## Required Sequence

Steps 1–7 apply to plan routes only; the **small** tier follows the journey
in Risk tiers instead (no plan file, no adversary passes, no READY gate).

0. Understand before planning: run a scoped local recon of the affected area
   and carry file:line findings into the plan (the task, for small).
   Recon is parent-only unless the user opts into a scout. Small tasks need a quick read.
1. Uncovered task: run `workflow/skills/plan-loop.md`; another task's READY
   plan does not cover it.
2. Otherwise read root `PLAN.md` and verify task coverage.
3. Continue only when the actual root `PLAN.md` has `Status: READY`; prompt
   wording such as "PLAN.md ready" is not proof.
4. Stop from `DRAFT`, `CHALLENGED`, missing `PLAN.md`, or missing concrete
   checks/required evidence.
5. Run `workflow/skills/adversary.md` before editing.
6. Fold accepted findings; reconcile criteria and Decision Log.
7. Re-review material deltas; implement only the approved current contract.
8. Implement the still-`READY` plan steps (the task, for small) in order with minimal, scoped
   changes. A code behavior change ships with its tests per
   `workflow/spec.md`; a bug fix starts from a failing test that reproduces
   the issue, a valid neighbor and an invalid neighbor. Preserve the bounded
   input domain and verify the decisive runtime/corpus when applicable. Repeated
   findings in one family trigger a method reassessment before another patch.
   At most one worker writes at a time: invoke it in the
   foreground, or wait for the worker and do not write until it returns. The
   parent remains the only canonical ledger writer and reads every integrated diff: a worker report locates the work,
   it does not evidence it.
9. Record progress in the ledger, task markers or nested check `last run`.
   Material plan facts require reconciliation and fresh approval; see
   `workflow/skills/execution-quality.md`.
10. If facts materially invalidate route, scope, checks, or required evidence,
    stop as `plan drift detected`; update `PLAN.md` and do not continue until it
    is refreshed to `READY`.
11. For material user-facing product-flow changes, exercise the strongest
    observable surface and record decisive legs that need a human as
    `blocked`, never `pass`. Pack integrity alone never counts as
    parent-observed execution.
12. Re-run the plan's focused checks after the product-flow check and each
    accepted fix — readiness never rests on checks predating the latest product-flow edit.
    Small tier (no plan): run the surface's own focused checks instead —
    the checks named by the task or the touched surface's suite.
12b. Simplification pass once checks are green. Walk **this diff only**.
    Stop at the first rung that holds; delete or rewrite what a higher rung
    already covers. No behavior change.

    1. Does this addition need to exist for the READY plan (the task, for small)? If not, delete it.
    2. Already in this repo? Reuse it; do not reimplement a nearby helper.
    3. Language builtin or stdlib?
    4. Native platform feature (HTML/CSS/OS/DB constraint)?
    5. Already-installed dependency?
    6. One straightforward expression or early return?
    7. Only then: the minimum that works.

    Cut from this change: unrequested interfaces/factories/config, comments
    restating the code, `any`/defensive try-catch hiding types, dead
    branches, duplicate helpers — readable beats clever. Never drop
    trust-boundary validation, data-loss handling, security, accessibility,
    or required tests.

    Re-run focused checks if anything was edited. Record `simplify: clean` or
    `simplify: removed N`. Autonomous runs also append
    `simplification_completed` with that evidence.
12c. Quality pass on the cumulative diff: invoke `code-quality` when the
    runtime exposes it, else the narrowest exposed domain or project skill,
    else compare the diff with 1–3 local sibling implementations. Append
    `quality_completed` with `status: pass` (evidence naming the producer)
    when a pass ran, or `status: unavailable` (evidence naming what is
    missing) with neither — then stop before completion; never present
    the missing pass as clean. Fix mechanical convention findings;
    report behavioral ones. Re-run focused checks if the pass edited anything.
    Skip only for pure docs or plan-only changes, and say so.
13. Review the **cumulative workspace patch that can ship** against `PLAN.md`
    per `workflow/skills/review.md` and `workflow/review-rubric.md`. Pin staged,
    unstaged, and relevant untracked implementation files in addition to the
    committed `git diff <merge-base-with-base-branch>...HEAD`. A clean
    single-commit branch may review that commit; per-slice reviews are insufficient.
    Pin once; dispatch fresh Logic and Spec hunters: both for high-risk;
    standard may use Daily Pi per `workflow/skills/review.md`. Autonomous
    runs require fresh context (subagent reviewer or cross-model).
    Record `reviewer_model` and whether deciding-code rows were complete. A
    `GO` without runtime deciding-code is invalid: `blocked` / re-review.
    Missing eligible runner or required authorization: `blocked`.
13b. Code-diff adversary per `workflow/skills/adversary.md`: tiered —
    **high-risk requires cross-model**; **standard accepts a documented
    double-sample same-family pass**; **small skips**. Single same-family pass
    alone → `blocked` (full autonomy policy).
    Name `adversary_model` (or `same-family-pass` ids).
    **High** findings: accept/reject via cross-model (or second sample), not
    the implementer alone. Fold accepted findings and re-run checks. Any
    accepted fix invalidates cumulative review and code-diff adversary evidence
    it can affect: re-review follows the review budget below.

    Review budget: one T/D/F counter per run (the ship phase inherits it).
    Default path: T1 clean → F1 clean on the pinned SHA → VALIDATE. When a
    round returns findings or a re-review is due, follow the bounded machine
    in `workflow/skills/review-rounds.md`; never validate past its ceiling.
    Record every pass in the review evidence: tour (T/D/FD/F + number),
    scope (full/delta), base SHA, patch SHA, reviewers. Close each round
    with one `review_completed` carrying `review_round` and `round_outcome`
    (after its adversary); `scripts/workflow-event` refuses a sequence the
    machine forbids.
14. Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`:
    fill `workflow/templates/plan-archive.md` (convention, hash gate and
    multi-repo rules: `workflow/plan-archive.md`); distill it as memory, do
    not raw-copy `PLAN.md`.
15. After archive and validation succeed, delete only root `PLAN.md`.
16. Otherwise keep it and report why.
17. Return files changed, tier, adversary result, validation, review result
    (including deciding-code completeness), archive path, deleted `PLAN.md`
    status (both N/A for small: no plan, no archive), remaining risks,
    next action if any, and final status.
18. Before any separately authorized push, run the complete relevant
    `scripts/verify-agentic-infra` group on the final diff. A red group blocks <!-- etabli-only -->
    push even when focused checks passed. When the diff touches scaffold docs,
    also run `scripts/workflow-ref-linter`. <!-- etabli-only -->

## Long loops

Open-ended improvement/benchmark loops follow `workflow/skills/long-loop.md`.

## Completion Evidence

Autonomous completion requires:

- recorded risk tier;
- adversary plan review (standard/high-risk);
- adversary code-diff review (standard/high-risk: named model or documented double-sample);
- focused validation;
- product-flow evidence when required by the plan;
- simplification pass result (`simplify: clean` or `simplify: removed N`);
- quality pass result (or explicit skip for docs/plan-only);
- Logic+Spec lead review on the cumulative shippable workspace patch with a
  complete deciding-code table for runtime diffs (self-review only for small
  tier);
- event ledger per `workflow/events.md` (mandatory for autonomous runs);
- implemented-plan archive under `docs/plan/` and root `PLAN.md` cleanup
  after successful archive and validation (when a plan existed; small tier
  has none).

## Autonomous evidence

Autonomous `plan-implement` runs must append `.workflow/<slug>/events.jsonl` and pass `scripts/workflow-event validate --profile autonomous-completed` before claiming completion.

Required product plans must pass `scripts/project-verification-check PLAN.md` before archive. Details: `workflow/product-verification.md`.
