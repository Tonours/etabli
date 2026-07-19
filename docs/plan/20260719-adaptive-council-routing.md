# Implemented: Adaptive, Token-Efficient Multi-Model Council

## Metadata

- Archived: 2026-07-19
- Source plan: Adaptive Council Routing And Bounded Deliberation
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main`

## Outcome

- Replaced explicit-only panel selection with deterministic proportional
  escalation on eligible routes: parent-only for score 0, one scout for score
  1, and a two-agent council for score 2 or more.
- Kept explicit controls: `single-agent`, `agent unique`, `no-panel`, and `sans
  panel` force parent-only execution; `multi-model`, `multi-agent`, `panel`,
  `cross-model`, `plusieurs modèles`, and `plusieurs agents` force a council on
  an eligible route.
- Added one real, bounded dialogue round. First passes are blind; only material
  unresolved claims may resume each exact original participant once. Sol may
  adjudicate once after both rebuttals complete.
- Kept Kimi K3 at Pi `xhigh` / provider `max` as a replacement only after an
  observed primary failure. It is never a silent primary, additional vote, or
  judge.
- Removed fixed wall-clock termination from model execution. Elapsed time is
  telemetry only; structural agent/round caps, requested and measured output
  budgets, provider failure, explicit cancellation, and no-progress rules
  remain the stop mechanisms.
- Did not import or depend on `karpathy/llm-council`. Etabli retains its useful
  blind-opinion and critique ideas without its fixed all-model ranking stage or
  repeated full-context fan-out.

## Context

- `claude/hooks/workflow-router-lib.mjs`: shared deterministic admission policy
  and Claude route packet.
- `pi/extensions/workflow-router.ts`: mechanical portfolio call, identity,
  completion, replacement, resume, and adjudication guards.
- `pi/extensions/lib/workflow-router-runtime.ts`: Pi execution instructions and
  requested output budgets.
- `workflow/skills/multi-model-orchestration.md`: canonical selection,
  conversation, provider, and evidence contract.
- `scripts/workflow-event` and `workflow/events.md`: backward-compatible
  protocol-v2 evidence validator.
- `workflow/runtime-capabilities.json`: expiring live capability evidence.
- `.workflow/adaptive-council/events.jsonl`: plan, review, validation, and live
  execution ledger.

## Decisions

### Escalate proportionally with inspectable signals

- Context: the previous blind benchmark found no quality gain from running a
  full panel on every eligible request and exceeded its 4x latency threshold in
  four of six repetitions.
- Choice: score bounded, category-deduplicated prompt evidence. Critical risk
  scores 2; system complexity, uncertainty, and literal repeated-failure
  history each score 1. Zero remains parent-only, one uses a route-appropriate
  Luna or Terra scout, and two or more uses a route-specific council with GLM.
- Rejected options: an extra LLM router call, automatic full panels, inferred
  hidden failure history, or vague intent such as `mode simple` and `agents
  autonomes`.
- Rationale: the policy is explainable, testable, and spends no model tokens to
  decide whether model tokens are warranted.
- Consequences: verification, CI repair, simple answers, sensitive operations,
  external mutation, and other ineligible routes remain parent-only even when
  prompt words resemble escalation signals.

### Use targeted dialogue instead of an all-to-all council

- Context: `llm-council` runs N first passes, N rankings that each receive all
  responses, then a chairman over responses and rankings. That duplicates
  context approximately quadratically and exposes no usage-budget contract.
- Choice: two blind first passes, deterministic checks, at most six anonymized
  material claims, one targeted resume per completed participant, and optional
  one-shot Sol adjudication over a compact dispute ledger.
- Rejected options: all-to-all rankings, transcript rebroadcast, majority vote,
  forced consensus, recursive delegation, and concurrent writers.
- Rationale: genuine counterargument is preserved while the parent remains the
  sole integrator and writer.
- Consequences: agreement and deterministic resolution stop before dialogue;
  resolved rebuttals stop before Sol.

### Enforce structural safety at the Pi tool boundary

- Context: prompt-only budgets could be bypassed by resuming the wrong agent,
  resuming before completion, adding Kimi as a vote, invoking Sol early, or
  launching portfolio roles through Task RPC.
- Choice: bind observed first-pass agent IDs to roles, require completed result
  evidence before resume, allow one resume per identity, require both completed
  rebuttals before Sol, admit Kimi only after an observed failed non-Kimi
  primary, and reject portfolio roles/models on `TaskCreate`, `TaskUpdate`, and
  `TaskExecute`.
- Rejected options: trusting coordinator prose or self-reported provenance.
- Rationale: call and round limits are mechanically enforceable with the
  available Pi hook surface.
- Consequences: short councils use guarded `Agent`; generic non-portfolio Task
  RPC remains a separately tracked capability.

### Treat token limits honestly and remove model wall-clock caps

- Context: Pi reports usage after completion and does not expose provider-hard
  mid-generation cancellation at the requested token boundary. Fixed operator
  timeouts also terminated healthy long-running adversaries without proving a
  model failure.
- Choice: enforce agent/round topology before calls, request exact output caps,
  measure usage after completion, and reject over-budget protocol-v2 evidence
  as accepted. Never terminate a healthy model solely because elapsed time
  crossed a fixed threshold.
- Rejected options: claiming requested output caps as provider-hard or using
  latency as a correctness gate.
- Rationale: evidence now distinguishes enforceable structure from observed
  resource use.
- Consequences: elapsed time remains visible. Explicit cancellation, provider
  errors, and workflow no-progress detection still terminate work when needed.

### Keep protocol-v2 evidence canonical and backward compatible

- Context: caller-selected budgets and loosely related fields could validate
  contradictory evidence.
- Choice: preserve historical events, but require exact v2 strategy budgets
  and coherent participant, model, round, disagreement, fallback, stop-reason,
  verdict, claim-count, and measured-usage shapes.
- Rejected options: rewriting legacy ledgers or accepting arbitrary budgets.
- Rationale: telemetry must be auditable rather than descriptive prose.
- Consequences: scout budget is `{claims:6, first_pass:600, rebuttal:0,
  adjudication:0, total:600}`; council budget is `{claims:6,
  first_pass:1800, rebuttal:700, adjudication:650, total:3500}`. A Kimi
  replacement marks the run degraded while preserving the actual resolution
  reason such as agreement, deterministic check, rebuttal resolution, or
  adjudication.

## Accepted Drift

- Original plan/spec: the first implementation draft included a 180-second
  real-probe assertion and later operator-driven 600-second adversary caps.
- Implemented reality: no model execution has a fixed wall-clock termination
  gate; local binary and Git diagnostic checks may still use short process
  timeouts because they are not model inference.
- Why accepted: the user explicitly removed the timeout caps, and structural
  plus token-efficiency controls already bound useful work more directly.

- Original plan/spec: a live Task RPC proof used a portfolio role/model.
- Implemented reality: portfolio execution is guarded through `Agent`; the
  Task RPC proof is generic and has no portfolio model override.
- Why accepted: otherwise Task RPC would bypass the identity and call-budget
  enforcement this change introduced.

## Validation Evidence

- `scripts/verify-agentic-infra all`:
  - result: PASS; 219 Pi tests and 32/32 router evaluation fixtures, with all
    shell, documentation, event, runtime, deploy, install, Nvim, and skill
    groups green.
- `RUN_REAL_MULTI_MODEL=1 PI_BIN=/Users/tonours/.asdf/shims/pi bash
  tests/multi-model-real-smoke.sh --conversation`:
  - result: PASS; agreement used two blind first passes, zero resumes, zero Sol,
    996 reported sidecar tokens, and 38,203 ms.
  - result: PASS; rebuttal used Luna agent `02e96ba9-8ecc-47b` and GLM agent
    `02cc0b8d-80b5-4cc`, resumed those exact IDs once each, used zero Sol, 1,962
    reported sidecar tokens, and 34,902 ms. Both probes left the worktree
    unchanged.
- `RUN_REAL_MULTI_MODEL=1 PI_BIN=/Users/tonours/.asdf/shims/pi bash
  tests/multi-model-real-smoke.sh --task-rpc`:
  - result: PASS; generic non-portfolio Task RPC proved spawn, completion, and
    `TaskGet` retrieval in 31,837 ms with 12,262 non-cache coordinator tokens;
    deterministic stop remains unproven and separately labelled.
- Protocol, routing, and trace fixtures:
  - result: PASS; deterministic admission is 32/32, all four degraded fallback
    resolution reasons have positive fixtures, contradictory v2 events are
    rejected, and agreement/deterministic/rebuttal/Sol call shapes are pinned.
- Kimi K3 xhigh/max code-diff adversary:
  - result: `GO WITH NOTES`; all four findings were accepted and fixed:
    observed-failure fallback admission, Task RPC bypass, preservation of the
    actual degraded stop reason, and completion-gated resumes.
- Fresh-context reviewer `/root/adaptive_council_fresh_review`:
  - result: final `GO`; no actionable finding remains after rechecking the live
    Task RPC shape and fallback-resolution fixtures.
- `git diff --check`:
  - result: PASS.

## Follow-up State

- Remaining risks: lexical signals can still produce false positives outside
  the maintained corpus; requested output limits are observable rather than
  provider-hard; deterministic TaskStop remains unproven; Kimi K3 and other
  live capability evidence expires after seven days.
- Parking lot: add structured prior-attempt counters only when the router has a
  trustworthy runtime source; expand hard blind fixtures before broadening the
  trigger vocabulary; re-probe providers after Pi/model upgrades.
- Superseded docs/specs: the explicit-only panel decision in
  `docs/plan/20260719-multi-model-execution-evaluation.md` remains historical
  and is superseded by this adaptive policy. The Kimi K3 fallback archive
  remains current for model configuration details.
- Next links: `workflow/skills/multi-model-orchestration.md`,
  `workflow/runtime-capabilities.json`, `workflow/events.md`, and
  `tests/multi-model-real-smoke.mjs`.
