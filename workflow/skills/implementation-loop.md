# Implementation Loop Contract

Shared contract for implementing `PLAN.md`; adapters hold harness details.
The full sequence governs plan-based implementation and all high-risk
contractual work — assess risk from the work itself; the route classifier
does not detect every high-risk change. Ordinary no-plan coding
keeps its route — a bounded runtime fix does not make it **small**; an
explicit plan request or multi-slice task uses the plan route, and an existing
DRAFT/CHALLENGED plan still blocks implementation. Select the route
(`workflow/spec.md` § Routing rules) before picking the tier.

## Risk tiers

Depth is proportional to risk. Pick the tier before step 1 and record it
(`tier: small|standard|high-risk`); upgrade at any step if the diff outgrows
the tier — never downgrade mid-run.

- **small** — docs-only, config-only, or a bounded single-surface edit with no
  runtime behavior change. Runs **outside the plan gate**: scoped recon
  (step 0), implement (step 8 semantics), checks (12), simplify (12b),
  quality (12c), report (17). One self-review of the cumulative diff
  replaces hunters and adversary passes. No plan file and no READY gate unless
  the surface is contractual — in which case the tier is not small.
- **standard** (default) — runtime code change on a known surface. Full
  sequence below, except step 13b accepts a documented same-family
  double-sample instead of cross-model.
- **high-risk** — kernel guards, installer/deploy scripts, harness eval
  infrastructure, security, multi-surface contract changes, or a third
  recurrence of the same failure. Full sequence, cross-model adversary
  mandatory (13b), both hunters mandatory (13).

## Standing rules

These hold at every step; `workflow/spec.md` § Rules is canonical and wins on
conflict.

- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`, emit a
  `no_progress` event, and list the eliminated hypotheses.
- Check-freeze: once the plan is `READY`, its Checks and Acceptance Criteria
  may only be strengthened or extended; weakening or removing one demotes the
  plan to `CHALLENGED` with a Decision Log rationale (CLI:
  `scripts/plan-check-freeze`).
- Before a mutable local-device or server action, name the exact target, the
  control path, and the post-check.
- A new transverse invariant ships with a mechanical check whose failure
  message names its remediation; the third occurrence of the same review
  finding becomes a mechanical check; instruction files stay maps, not manuals.
- In autonomous runs a session handoff is a `handoff` event (branch, sha, done,
  pending, next action, do-not-redo); a started migration is finished or handed
  off that way, never left half done.

## Required Sequence

0. Understand before planning: run a scoped local recon of the affected area
   and carry sourced findings (file:line) into the plan. Recon is parent-only
   by default. Dispatch a scout sidecar only when the user explicitly opts in.
   Scale recon down to a quick read for small tasks; never skip it entirely.
1. If a task is provided, run `workflow/skills/plan-loop.md` first.
2. If no task is provided, read the existing root `PLAN.md`.
3. Continue only when the actual root `PLAN.md` has `Status: READY`; prompt
   wording such as "PLAN.md ready" is not proof.
4. Stop from `DRAFT`, `CHALLENGED`, missing `PLAN.md`, or missing concrete
   checks/required evidence.
5. Run the adversary contract in `workflow/skills/adversary.md` before editing
   (standard/high-risk; optional for small).
6. Fold accepted adversary findings into `PLAN.md`.
7. If blockers remain, set `Status: CHALLENGED` and stop.
8. Implement the still-`READY` plan steps in order with minimal, scoped
   changes. A code behavior change ships with its tests per
   `workflow/spec.md`; a bug fix starts from a failing test that reproduces
   the issue. At most one worker writes at a time: invoke it in the
   foreground, or wait for the worker and do not write until it returns. A
   READY plan may opt into `workflow/skills/program-orchestration.md`; then
   its manifest concurrency/isolation/scope/artifact/verifier rules replace
   the single-worker limit. The parent remains the only canonical ledger
   writer and reads every integrated diff: a worker report locates the work,
   it does not evidence it.
9. Update `PLAN.md` only for progress or newly discovered facts.
10. If facts materially invalidate route, scope, checks, or required evidence,
    stop as `plan drift detected`; update `PLAN.md` and do not continue until it
    is refreshed to `READY`.
11. For material user-facing product-flow changes or explicit dogfood
    requests, run `workflow/skills/product-dogfood.md` (flow map, scenario
    matrix, strongest observable surface, honest blocked legs, re-run after
    each accepted fix). A plan that omitted that evidence means plan drift:
    strengthen the checks before continuing. Durable product/UI claims use
    `scripts/evidence-proof` (etabli repo only); pack integrity alone never
    counts as parent-observed execution.
12. Re-run the plan's focused checks after dogfood and each accepted fix —
    readiness never rests on checks predating the latest product-flow edit.
12b. Simplification pass once checks are green. Walk **this diff only**.
    Stop at the first rung that holds; delete or rewrite what a higher rung
    already covers. No behavior change.

    1. Does this addition need to exist for the READY plan? If not, delete it.
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
    else compare the diff with 1–3 local sibling implementations. With
    neither, record `quality: unavailable` and stop before completion; never
    present the missing pass as clean. Fix mechanical convention findings;
    report behavioral ones. Re-run focused checks if the pass edited anything.
    Skip only for pure docs or plan-only changes, and say so.
13. Review the **cumulative workspace patch that can ship** against `PLAN.md`
    per `workflow/skills/review.md` and `workflow/review-rubric.md`. Pin staged,
    unstaged, and relevant untracked implementation files in addition to the
    committed `git diff <merge-base-with-base-branch>...HEAD`; a single-commit
    branch may review that commit alone only when the workspace is clean.
    Per-slice reviews do not satisfy this step.
    Pin the patch once, then dispatch Logic hunter and Spec hunter in fresh
    context (both mandatory for high-risk; standard may follow the Daily Pi
    exception in `workflow/skills/review.md`; autonomous runs use fresh
    context (subagent reviewer or cross-model) per `workflow/spec.md`).
    Record `reviewer_model` and whether deciding-code rows were complete. A
    `GO` with empty runtime deciding-code is invalid — treat as `blocked` /
    re-review. Without an eligible runner or authorization when required,
    stop as `blocked` requesting review.
13b. Code-diff adversary per `workflow/skills/adversary.md`: tiered —
    **high-risk requires cross-model**; **standard accepts a documented
    double-sample same-family pass**; **small skips**. Single same-family pass
    alone → `blocked` (full autonomy policy).
    Name `adversary_model` (or `same-family-pass` ids).
    **High** findings: accept/reject via cross-model (or second sample), not
    the implementer alone. Fold accepted findings and re-run checks. Any
    accepted fix invalidates cumulative review and code-diff adversary evidence
    it can affect: pin the new final patch and repeat both passes.
14. Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`:
    fill `workflow/templates/plan-archive.md` (convention, hash gate and
    multi-repo rules: `workflow/plan-archive.md`); distill it as memory, do
    not raw-copy `PLAN.md`.
15. After archive and validation succeed, delete only the current workspace root
    `PLAN.md`.
16. If archiving is skipped or fails, keep `PLAN.md` and report why.
17. Return files changed, tier, adversary result, validation, review result
    (including deciding-code completeness), archive path, deleted `PLAN.md`
    status, remaining risks, next action if any, and final status.
18. Before any separately authorized push, run the complete relevant
    `scripts/verify-agentic-infra` group on the final diff. A red group blocks
    push even when focused checks passed.

## Long-Loop Budget Discipline

For any improvement loop without a natural fixed end (coverage hillclimbs,
iterative optimization, repeated benchmark attempts), declare an explicit
campaign budget before starting: a maximum iteration count or wall-clock span
scaled to the session's expected limit. Separately declare the maximum silence
between progress observations and a command timeout sized from a measured
baseline or documented project expectation. Freeze one metric command. Deliver the
progression achieved inside the budget — at least three measured values in
the final answer, the current state, and the single next lever — then stop
before an external cap and report. Freeze the project's documented
test/coverage command, not an experimental coverage runner over a live HTTP
server. After two red serve-or-coverage attempts, park that path, write the
measured rows, and stop. About 60 seconds without an observable update is a
prompt to report progress or inspect the process; it is not a universal command
timeout. Abort only at the predeclared command or campaign bound.
A delivered partial progression with an honest stop beats being cut off
mid-iteration: being killed is not evidence of diligence, and an unfinished
iteration proves nothing.

## Completion Evidence

Autonomous implementation loops are complete only when the final state contains
evidence for all of:

- recorded risk tier;
- adversary plan review (standard/high-risk);
- adversary code-diff review (named model or documented double-sample);
- focused validation;
- product dogfood scenario evidence when required by the plan;
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
