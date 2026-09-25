# Self-Improvement Loop Contract

Shared contract for improving Etabli itself from observed workflow evidence.

The loop is local-first and reviewed. It turns recurring failures into safer
workflow changes without bypassing `PLAN.md`, validation, or human checkpoints.
The model may propose harness changes, but evaluator and permission controls
stay outside the mutation loop.

## Privacy boundary

The public repository may contain only a sanitized contract, synthetic fixtures,
opaque fingerprints and aggregate results that do not reveal private work. Raw
corpora, prompts, session traces, detailed reviewer history, operational
metrics and other sensitive evidence stay out of Git. For private evidence,
route storage by project context: use **Obvault** outside the managed work
context and **Brain** inside that context. Do not dual-write the same private record to both
stores; keep only a redacted pointer or aggregate public receipt in Etabli.

## Inputs

Use evidence that can be inspected again:

- `.workflow/<slug>/events.jsonl`;
- implemented plan archives in `docs/plan/`;
- validation failures and no-progress events;
- accepted adversary or review findings;
- router misses and guard failures;
- dogfood blockers;
- runtime capability overclaims;
- harness failure records with terminal cause, causal status, mechanism,
  verifier, and trace links.

Do not use vibes, stale memory, or a single anecdote as enough proof for a
workflow invariant.

With explicit provider-egress approval, `jev-judge evaluate
self-improvement-candidate` may shadow-classify a bounded candidate and observed
outcome. Separately, `jev-judge prepare-self-improvement` and the explicit-live
diagnosis path make Jev the required semantic producer of the friction pattern
from one complete sanitized observation; code derives target and actionability
from that pattern. No accepted Jev result means no semantic diagnosis;
deterministic code does not invent a fallback. The controller skips Jev on a
completed, verified, friction-free episode (`no_friction_signals`): eligibility,
not diagnosis. Ask Jev only the semantic judgment; keep policy in code.
The evidence requirements, candidate acceptance, PLAN gate, evaluator, and all
mutation permissions in this contract remain deterministic authority.

For post-run harness traces, use `workflow/trace-self-improvement.md`. The
`prototype_offline` extractor observes explicitly selected Pi or Claude
episodes. `scripts/jev-self-improvement --live` adds an explicit, bounded
`diagnose_shadow` controller for one natively correlated Pi episode: code reads
the selected trace and ledger, sends only normalized counters and enums to one
retry-disabled Jev diagnosis unless the episode is friction-free, and emits a private terminal `no_op` or
`investigate` packet. Unknown, partial, unbound, secret-like, symlinked, or
inconsistent input fails closed. Single-episode diagnosis currently never
produces `candidate`; any future producer (cross-episode recurrence) remains suppressed
unless a current fingerprint-bound `propose_reviewed` capability receipt proves
the synthetic suite, three distinct live checks, and independent cross-model
verification. Even then the packet is non-executable and applying it requires a
new user-invoked READY `plan-implement` run. Automatic promotion remains
unavailable.

## Harness Improvement Loop

Use a Self-Harness-style loop when the improvement target is the workflow,
router, memory, permissions, checks, or harness code:

1. Weakness mining: cluster failures into verifier-grounded patterns. Record
   the terminal verifier-level cause, whether the agent behavior is actually
   causal, the exposed harness mechanism, and the traces that prove it.
2. Bounded proposal: propose narrow edits from an explicit context containing
   editable surfaces, mined failure patterns, passing behaviors to preserve,
   and previously attempted edits.
3. Proposal validation: freeze one objective before the run: quality,
   efficiency, or reliability. Accept only candidates that meet its metric and
   do not regress held-out router, docs, event, or workflow smoke
   checks. When baseline and candidate use the same comparable population,
   record `harness_validation_completed` with the same stable population
   identifier on both sides, integer pass counts, checks, and evidence. New
   strict comparisons also bind exact baseline/candidate artifact fingerprints,
   manifest bytes, objective/metric/threshold, manifest-frozen measurement population when
   applicable, and the evaluator bundle. Quality requires a strict held-in gain;
   efficiency or reliability may preserve held-in quality while improving
   their frozen metric. Every objective requires held-out non-regression, no
   baseline safety gap, and no baseline-pass to candidate-fail transition by
   task ID. Retest the combined accepted artifact before promotion.
4. Rejection logging: record rejected candidates and negative results with the
   reason, regressions, and evidence so future runs do not repeat them.

`held_out` is adaptive validation once it participates in repeated candidate
decisions. Never describe it as an intact final test. Estimate transfer with a
sealed surface consulted once after selection, then with future real tasks; once
opened for diagnosis, that surface joins validation and must be renewed.

Do not collapse unrelated candidate suites into one harness-improvement
average. Report proposal coverage, verdicts, and percentage-point deltas per
candidate; unavailable or non-comparable evidence remains `null` or uses the
non-comparative candidate events.

## Candidate Outcomes

Each candidate ends as one of:

- `no_op`: evidence is weak, isolated, stale, or already covered;
- `recommendation`: useful but not yet implementation-ready;
- `router_fixture`: a prompt/route pair that prevents a real routing miss;
- `contract_patch`: a bounded update to `workflow/spec.md` or
  `workflow/skills/`;
- `mechanical_check`: hook, smoke assertion, fixture, lint, or helper test;
- `rejected`: candidate failed validation, overfit the evaluator, weakened
  permission boundaries, or lacked ownership.

`workflow-retrospect` may report candidates, but it never applies patches,
pushes, posts, deploys, or changes external systems.

## Required Sequence

1. Inspect current repo state and relevant evidence sources.
2. Run or consult `scripts/workflow-retrospect` when recurring evidence is the <!-- etabli-only -->
   question.
3. Classify each candidate with source paths, confidence, proposed outcome, and
   held-in / held-out validation surfaces.
4. Reject candidates without repeatable evidence, clear ownership, or a
   validation surface.
5. Reject candidates that would reward-hack a narrow test, hide negative
   results, collapse diversity into the same proposal, or move oversight inside
   the evolving harness.
6. For accepted candidates, create or refresh `PLAN.md`; implementation starts
   only from `Status: READY`.
7. Implement the smallest reviewed change that closes the evidence-backed gap.
8. Add or update a mechanical check whenever the change creates a transverse
   invariant.
9. Run focused checks and record results in the event ledger when the run is
   autonomous.
10. Archive the implemented plan only after validation, then delete the root
   `PLAN.md`.

## Token lens

Context cost is a first-class self-improvement input. The frozen metric is
`scripts/workflow-context-budget` over the surfaces declared in <!-- etabli-only -->
`workflow/runtime/context-budget.json`: the characters an agent loads for a
route, or on every turn, with one ceiling per surface.

- Inputs: `scripts/workflow-context-budget --json`; the `context budget`,
  `telemetry` and `terminal` sections of `scripts/workflow-retrospect`; <!-- etabli-only -->
  measured `outcome_metric` events, never synthesized ones.
- Ratchet-only: after a validated trim, `scripts/workflow-context-budget
  --ratchet` lowers ceilings to `ceil(chars * 1.03)`; it never raises one. A
  raise is a reviewed diff of the budget file with a Decision Log rationale,
  never a silent edit. Moving prose into a file outside every surface is a
  review finding, not a saving.
- Cycle: retrospect (headroom, largest files, telemetry coverage, terminal
  counts) → candidates classified as above → READY `PLAN.md` → trim or move
  with pointers, rules never deleted → focused checks → `--ratchet` → the core
  gate holds the new floor for the next cycle.
- Unattended bound: a `recurring-run` may execute `scripts/workflow-retrospect` <!-- etabli-only -->
  and write only its report under `.workflow/<slug>/`. It never edits contract
  files, never runs `--ratchet`, never authors or promotes `PLAN.md`. Applying
  a candidate requires a user-invoked `plan-implement`.
- Counter-metric: a rise in `blocked` or `no_progress` terminal outcomes after
  a trim is evidence that a rule left the hot path; restore it before trimming
  further.

## Safety Gates

- Never weaken checks to make self-improvement pass.
- Never auto-apply `workflow-retrospect` output.
- Never synthesize token usage or treat `measured:true` without token totals as
  usage coverage. Historical recovery requires an explicit dry-run review and
  `--apply` against the active non-terminal ledger.
- Never accept a candidate on held-in evidence alone when a relevant held-out
  smoke, fixture, or review surface exists.
- Never convert `proxy_supported`, `blocked`, or `unknown` runtime capability
  labels into `confirmed` without the proof command.
- Never create external write-back, deploy, push, merge, billing, production,
  or secret-touching behavior without an explicit command contract.

## Completion Evidence

A self-improvement run is complete only when the final handoff names:

- evidence sources inspected;
- candidates accepted and rejected;
- files changed;
- mechanical checks added or deliberately not needed;
- validation commands and results;
- archive path or explicit blocker.
