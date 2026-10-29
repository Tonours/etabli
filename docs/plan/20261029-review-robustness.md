# Implemented: Cross-model code-diff adversary by default, sourced plan facts, PR body freshness

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — Review robustness phase 1: cross-model code-diff adversary by default, sourced plan facts, PR body freshness
- Source plan SHA-256: `f9d14846444f1f9051a70a06b9428d511fa73559d5554ea7e95fe89e5a706e17`
- Status: IMPLEMENTED
- Commit / branch: `feat/review-robustness`, based on `ae196bbf`
- Workflow initiative: review-robustness

## Outcome
- Cross-model by default (AC-1): the code-diff adversary is cross-model at
  standard and high-risk tiers. A same-family double-sample replaces it only at
  standard tier, and only when every eligible route is technically
  unavailable: launch error, network, auth, quota or rate limit, or a timeout
  of at least 30 minutes fixed before launch. The run records
  `cross_model: unavailable (<category>)` and a residual-risk line. An answer
  without provenance, or truncated, is rerun once and then `blocked`, never a
  fallback. A `BLOCK` verdict or a wait under the deadline is never
  unavailability. Same rule in the implementation-loop tiers, step 13b and
  Completion Evidence, the adversary contract, the adversary skill and the
  glossary.
- Sourced plan facts (AC-2): plan-loop step 1 requires a `path:line` or a
  command with its output for every fact an AC, step or check depends on. The
  plan adversary re-opens them, so a contradicted or unsourced load-bearing
  fact is a finding. Both PLAN templates carry the hint.
- PR body freshness (AC-3): before each push to a branch with an open PR, the
  body is re-read against the final diff and stale claims are fixed
  (`workflow/pr-body-contract.md` § Honest status, implementation-loop
  step 18).

## Context
- `workflow/skills/implementation-loop.md`: small tier already excludes any
  behavior change, and high-risk already covers multi-surface contract
  changes. A tier-based rule therefore needs no "runtime file" classifier.
  A classifier was rejected: an extensionless script reads as `text/plain`.
- `AGENTS.md` risk-tier line: standard agent-surface link changes already
  demanded one cross-model pass. It stays, and it is stricter than the new
  fallback.

## Decisions
### Split the six-item improvement plan
- Context: seven cross-model plan rounds on one wide design (mutation probe,
  context pack, patch chunking, private bench, proof tests, plus these
  contract changes) all came back CHALLENGED, and each fold opened new
  surfaces.
- Choice: phase 1 ships the contract changes that need no measurement. Each
  tool becomes its own plan, opened by a throwaway measurement
  (AGENTS.md § Growth).
- Rejected options: keep folding the wide plan.
- Consequences: phase 2 starts from the round findings, kept privately.

## Accepted Drift
- Original plan/spec: AC-1 surfaces listed implementation-loop, adversary
  contract and adversary skill.
- Implemented reality: `GLOSSARY.md` "Double-sample" also changed. The plan
  grep was case-sensitive and missed it; the T1 Logic hunter caught it.
- Why accepted: the glossary was the same rule, stale.

## Validation Evidence
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 13/13 and 42/42 on the final commit.
- command: `bun test pi/extensions/__tests__/`
  - result: 62 pass, 0 fail.
- command: `bash tests/workflow-scaffold-smoke.sh`
  - result: ok. It asserts each new rule fragment present and each old one
    absent, in the scaffolded copy or the source.
- Mutation check (private driver): every assertion pair was mutated by
  putting the old fragment back or removing the new one. 28/28 mutations
  turned the smoke red.
- Decision probes (private): a fresh model with no tools read the contract
  excerpt and answered seven runner scenarios. The new texts scored 7/7. On
  the old texts, "route works but is slow, a double-sample is faster" gave a
  double-sample; the new texts give cross-model.
- Privacy grep against a private term list over every commit's tree,
  message, people fields and added lines: 0.

## Review
- Plan: rounds 8 to 11 on the phase-1 plan, cross-model (`gpt-6.1-sol`);
  READY at round 11 with no high finding left.
- T1: Spec no findings. Logic found 1 low (the stale glossary). The
  cross-model adversary returned BLOCK on 2 medium and 1 low: the provenance
  rerun was not scoped to answered runs, per-attempt evidence was missing,
  and an assertion was missing. All were fixed.
- T2: Logic GO with no findings. Spec raised 1 medium: mirror the rerun rule
  in step 13b and the skill. The adversary raised 1 low: scope the push case
  to the freshness check. Both folded.
- D1: Logic GO; Spec no findings. The adversary flagged 1 medium wording
  ambiguity ("then `blocked`"), which was folded.
- D2: Logic GO; cross-model GO, no findings.

## Follow-up State
- Remaining risks: the fallback relies on the agent classifying
  unavailability honestly. The closed category list, the try-every-route
  rule and per-attempt evidence limit gaming, but no machine check enforces
  them. The decision probes are a proxy, not runtime proof.
- Parking lot: phase-2 plans, one per tool, each opened by a throwaway
  measurement: mutation probe, out-of-diff context pack, patch chunking with
  a private bench, proof tests.
- Superseded docs/specs: none.
- Next links: the phase-2 mutation probe plan.
