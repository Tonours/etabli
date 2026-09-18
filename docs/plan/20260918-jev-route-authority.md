# Implemented: Promote Jev to bounded local route authority

## Metadata
- Archived: 2026-09-18
- Source plan: `PLAN.md` — Promote Jev from route shadowing to bounded local route authority
- Source plan SHA-256: `04c862896a1b33158691318d12e4a0ba45f5c1af625c6eca98be77d482f245f8`
- Status: IMPLEMENTED
- Commit / branch: uncommitted workspace patch
- Workflow initiative: none

## Outcome
- TypeSafe Jev now selects eligible Pi workflow routes in local `enforced` mode when its pinned Choice answer passes confidence, argmax, and probability-margin gates.
- Deterministic code retains authority over destructive or external actions, protected routes, actual plan state, mutation guards, permissions, receipt persistence, and provider failure.
- Pi awaits enforced decisions and injects the selected route contract into the model-facing system prompt before the turn starts.
- Promotion requires checked-in live evidence bound to the model, corpus, question, thresholds, runtime parameters, and decisive source files.
- The local CLI supports health, one-shot evaluation, synthetic replay, and explicit live calibration. No listener, server, container, VPS path, remote runtime, or stored credential exists.

## Context
- `workflow/spec.md`: canonical workflow and authority boundary.
- `workflow/semantic-judgment.md`: operational modes, safety rules, calibration evidence, and rollback.
- `workflow/runtime/semantic-judgment-policy.json`: pinned model, thresholds, promotion gates, and `enforced` mode.
- `workflow/runtime/jev-route-promotion.json`: validated 90-observation live promotion artifact.
- `pi/extensions/lib/route-shadow.mjs`: promotion validator, runtime selection, failover, and hardened receipts.
- `pi/extensions/workflow-router.ts`: awaited Pi integration and route-contract injection.

## Decisions
### Give Jev bounded semantic authority
- Context: regex routing missed semantically varied requests, while the prior shadow integration could only observe.
- Choice: accept Jev only for eligible closed-set route selection above frozen confidence and top-two margin thresholds.
- Rejected options: unrestricted model authority; removing the deterministic classifier; retaining shadow-only operation after passing promotion evidence.
- Rationale: Jev improves semantic routing while code continues to own policy and execution safety.
- Consequences: provider availability is optional at runtime; uncertain or failed decisions fall back locally.

### Bind promotion to recomputable evidence
- Context: synthetic replay and self-reported aggregate metrics cannot justify authority.
- Choice: retain raw probabilities for 30 cases over three live repetitions, recompute deterministic routes, protected annotations, thresholds, calibration metrics, stability, cost, and aggregate gates at startup.
- Rejected options: a manually asserted pass flag; one observation per case; trusting stored deterministic choices.
- Rationale: enforced mode must fail closed when evidence, code, policy, model, or corpus drifts.
- Consequences: relevant source changes invalidate the manifest and require a new live calibration.

### Require durable local provenance
- Context: an authoritative decision without a receipt cannot be audited.
- Choice: write sanitized receipts through symlink-safe local file handling and revert to deterministic routing when persistence fails.
- Rejected options: best-effort receipt persistence in enforced mode; raw prompts or provider payloads in receipts.
- Rationale: authority and provenance must succeed together.
- Consequences: receipt-path faults reduce semantic coverage without blocking the workflow.

## Accepted Drift
- Original plan/spec: the first promotion gate covered accuracy, safety, provider errors, and latency.
- Implemented reality: independent review added three repetitions, prediction stability, Brier score, expected calibration error, confusion data, cost, real deterministic-route recomputation, and decisive-source fingerprints.
- Why accepted: these checks close evidence-integrity gaps without expanding Jev's authority.

## Validation Evidence
- command: live TypeSafe calibration with `ETABLI_CALIBRATION_REPETITIONS=3`
  - result: 90 observations over 30 unique cases; 93.3% raw accuracy, 100% accepted accuracy, 65.6% accepted coverage, 100% override accuracy, 66.7% accepted override coverage, 100% protected preservation, 100% stability, Brier `0.099333`, ECE `0.039778`, zero provider errors, p95 `386 ms`, input cost `$0.003393`; every frozen gate passed.
- command: real local `scripts/jev-shadow evaluate` with zsh-inherited credential and `ETABLI_SEMANTIC_MODE=enforced`
  - result: Jev changed deterministic `answer` to `verify`, reported `semantic_override`, and persisted one sanitized receipt in an isolated temporary root.
- command: `scripts/verify-agentic-infra core`
  - result: 20/20 checks passed, including 275 Pi tests, typecheck, Jev smoke, and 212/212 deterministic router evaluations.
- command: focused semantic smoke, targeted Pi extension/runtime tests, and `git diff --check`
  - result: passed; enforced selection, fallback, active-plan guards, argmax/margin checks, stale/tampered manifest rejection, and receipt symlink protection are covered.
- command: independent Claude review followed by focused Claude re-review
  - result: initial evidence-integrity and calibration-bin findings were fixed; re-review returned PASS.
- command: final Spec release review
  - result: PASS with no actionable finding on the final snapshot.

## Follow-up State
- Remaining risks: the corpus is bounded and prompt-only; the context-dependent `linear-work` case remains a stable raw misclassification, contained by its protected deterministic route. Future corpus, model, question, policy, or decisive-source changes require recalibration.
- Parking lot: extend the corpus from real sanitized routing incidents and compare workflow outcome quality before expanding Jev beyond route selection.
- Superseded docs/specs: the mistaken shadow/VPS archive was removed; current runtime is strictly local and contains no server or deployment path.
- Next links: `workflow/semantic-judgment.md`, `workflow/runtime/semantic-judgment-policy.json`, and `workflow/runtime/jev-route-promotion.json`.
