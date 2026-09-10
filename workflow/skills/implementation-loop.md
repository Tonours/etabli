# Implementation Loop Contract

Shared contract for implementation from `PLAN.md`.

Pi skills and Claude commands are runtime adapters over this file. Keep harness
details in the adapters; keep the phase order and completion evidence here.

Select the route from `workflow/spec.md` before applying this loop's risk tiers.
The full sequence governs plan-based implementation. Ordinary no-plan coding
keeps its existing route, even for a bounded runtime fix; that does not make the
change **small**. An explicit plan request or multi-slice task uses the plan
route, and an existing DRAFT/CHALLENGED plan still blocks implementation.
High-risk contractual work requires the full sequence. Assess that risk from
the work itself; the route classifier does not detect every high-risk change.

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
   the issue. By default, writing a step may be delegated to at most one
   worker at a time when the runtime exposes one, never two in parallel.
   Invoke that worker in the foreground; if the runtime backgrounds it, wait
   for the worker to finish and do not write until it returns. A READY plan
   may opt into `workflow/skills/program-orchestration.md`; then its manifest
   concurrency, isolated worktree, non-overlapping scope, artifact, and
   independent-verifier rules replace that single-worker limit. The parent
   remains the only canonical ledger writer and reads every integrated diff:
   a worker report locates the work, it does not evidence it.
9. Update `PLAN.md` only for progress or newly discovered facts.
10. If facts materially invalidate route, scope, checks, or required evidence,
    stop as `plan drift detected`; update `PLAN.md` and do not continue until it
    is refreshed to `READY`.
11. For material user-facing product-flow changes, or any explicit dogfood
    request, run the product dogfood contract in
    `workflow/skills/product-dogfood.md`: map flows, derive the scenario matrix,
    execute the strongest available observable surface, record blocked external
    legs honestly, and re-run failed plus adjacent scenarios after each
    accepted fix. If the plan omitted dogfood evidence for such a change, stop
    as plan drift and strengthen the checks before continuing.
    Durable product/UI claims use `scripts/evidence-proof` (etabli repo
only); pack integrity alone
    never counts as parent-observed execution.
12. Run focused checks from the plan after dogfood and after any accepted
    dogfood fix, so readiness is never based on checks that predate the latest
    product-flow edit.
12b. Simplification pass once checks are green. Walk **this diff only**.
    Stop at the first rung that holds; delete or rewrite what a higher rung
    already covers. No behavior change.

    1. Does this addition need to exist for the READY plan? If not, delete it.
    2. Already in this repo? Reuse it; do not reimplement a helper a few files
       over.
    3. Language builtin or stdlib?
    4. Native platform feature (HTML/CSS/OS/DB constraint)?
    5. Already-installed dependency?
    6. One straightforward expression or early return?
    7. Only then: the minimum that works.

    Cut from this change: unrequested interfaces/factories/config, comments
    that restate the code, `any`/defensive try-catch that only hides types,
    dead branches, duplicate helpers. Readable beats clever. Never drop
    trust-boundary validation, data-loss handling, security, accessibility, or
    the tests this contract requires for a behavior change.

    Re-run focused checks if anything was edited. Record `simplify: clean` or
    `simplify: removed N`. Autonomous runs also append
    `simplification_completed` with that evidence.
12c. Quality pass on the cumulative diff: invoke `code-quality` when the
    runtime exposes it. Otherwise load the narrowest exposed domain or project
    skill. If no matching skill is exposed, compare the diff directly with
    1–3 local sibling implementations. If neither a skill nor a relevant
    sibling exists, record `quality: unavailable` and stop before completion;
    never present the missing pass as clean. Fix mechanical convention
    findings; report behavioral ones. Re-run focused checks if the pass edited
    anything. Skip only for pure docs or plan-only changes, and say so.
13. Review the **cumulative** implementation diff against `PLAN.md` per
    `workflow/skills/review.md` and `workflow/review-rubric.md`:
    scope is `git diff <merge-base-with-base-branch>...HEAD` when the branch has
    more than one implementation commit; a single-commit branch may review that
    commit alone. Per-slice reviews do not satisfy this step.
    Pin the patch once, then dispatch Logic hunter and Spec hunter in fresh
    context (both mandatory for high-risk; standard may follow the Daily Pi
    exception in `workflow/skills/review.md`). In an autonomous run, hunters
    come from a fresh context (subagent reviewer or cross-model) per
    `workflow/spec.md`. Record `reviewer_model` and whether deciding-code rows
    were complete. A `GO` with empty runtime deciding-code is invalid — treat
    as `blocked` / re-review. For **small** tier, a single documented
    self-review of the cumulative diff replaces this step.
    Without an eligible runner or authorization when required, stop as
    `blocked` requesting review.
13b. Code-diff adversary per `workflow/skills/adversary.md`: tiered —
    **high-risk requires cross-model**; **standard accepts a documented
    double-sample same-family pass**; **small skips**. Single same-family pass
    alone → `blocked` (full autonomy policy).
    Name `adversary_model` (or `same-family-pass` ids).
    **High** findings: accept/reject via cross-model (or second sample), not
    the implementer alone. Fold accepted findings and re-run checks.
14. Archive the final implemented plan in `docs/plan/YYYYMMDD-short-slug.md`
    using `workflow/plan-archive.md`; distill it as memory, do not raw-copy
    `PLAN.md`.
15. After archive and validation succeed, delete only the current workspace root
    `PLAN.md`.
16. If archiving is skipped or fails, keep `PLAN.md` and report why.
17. Return files changed, tier, adversary result, validation, review result
    (including deciding-code completeness), risks, archive path, deleted
    `PLAN.md` status, remaining risks, next action if any, and final status.
18. Before any separately authorized push, run the complete relevant
    `scripts/verify-agentic-infra` group on the final diff. A red group blocks
    push even when focused checks passed.

## Long-Loop Budget Discipline

For any improvement loop without a natural fixed end (coverage hillclimbs,
iterative optimization, repeated benchmark attempts), declare an explicit
budget before starting: a maximum iteration count or wall-clock span scaled
to the session's expected limit. Freeze one metric command. Deliver the
progression achieved inside the budget — at least three measured values in
the final answer, the current state, and the single next lever — then stop
before an external cap and report. Freeze the project's documented
test/coverage command, not an experimental coverage runner over a live HTTP
server. After two red serve-or-coverage attempts, park that path, write the
measured rows, and stop. If one metric command exceeds about 60s, abort it.
A delivered partial progression with an honest stop beats being cut off
mid-iteration: being killed is not evidence of diligence, and an unfinished
iteration proves nothing.

## Completion Evidence

Autonomous implementation loops are complete only when the final state contains
evidence for all of:

- recorded risk tier;
- adversary plan review (standard/high-risk);
- adversary code-diff review with named model (or documented double-sample;
  skipped only for small tier);
- focused validation;
- product dogfood scenario evidence when required by the plan;
- simplification pass result (`simplify: clean` or `simplify: removed N`);
- quality pass result (or explicit skip for docs/plan-only);
- Logic+Spec lead review on the cumulative merge-base...HEAD scope with
  complete deciding-code table for runtime diffs (self-review only for small
  tier);
- event ledger per `workflow/events.md` (mandatory for autonomous runs);
- implemented-plan archive under `docs/plan/` (when a plan existed;
  skipped for the small tier, which requires no PLAN.md);
- root `PLAN.md` cleanup after successful archive and validation (when a
  plan existed; skipped for the small tier).

## Autonomous evidence

Autonomous `plan-implement` runs must append `.workflow/<slug>/events.jsonl` and pass `scripts/workflow-event validate --profile autonomous-completed` before claiming completion.
