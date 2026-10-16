# Implemented: severity-gated review rounds, a clean T1 closes the review

## Metadata
- Archived: 2026-10-15
- Source plan: `PLAN.md` — P1 — revue convergente : budget de revue gaté par la sévérité, un T1 propre clôt la revue
- Source plan SHA-256: `2c5cb63f5f46e2120a1dec46cbf7eed0b35daff6bd01a9e11f47991545773ce4`
- Status: IMPLEMENTED
- Commit / branch: `feat/convergent-review` (uncommitted at archive time)
- Workflow initiative: convergent-review

## Outcome
- `scripts/lib/review-rounds.jq` runs a T/D machine: a round is `clean` when its review is not `BLOCK` and every code_diff adversary of the round is `GO`/`GO WITH NOTES` with an `accepted_findings` array free of `blocking: true`. A clean round closes the review; non-blocking findings never spend a round.
- Blocking findings keep a bounded re-review: T1 → T2 → D1 → D2; D widening → next unspent T; nothing left → `blocked`. At most four rounds.
- The machine requires a code_diff adversary for every T round, for a D round after a `findings` round and for a D round whose window holds a contractual `file_changed`; at least one must follow the round's last `file_changed`. An adversary after the closing round is an error once no round remains or `completed` exists.
- Ledgers already holding F1/F2/FD keep the legacy T→F machine; append mode refuses a first F round in a ledger that has none.
- `autonomous-completed` (bash profile and its jq batch mirror) delegates adversary freshness to the round machine for new-machine ledgers.
- Prose (`review-rounds.md`, `implementation-loop.md` 13b, `adversary.md`, `events.md`, `ship.md` 4/7) describes the new machine; `review-rounds.md` shrinks from 79 to 71 lines.

## Context
- Ledger census since 2026-09-27: 26 `plan-implement`/`implement` runs, 14 `blocked`, median 7 adversary passes and 5 reviews per run.
- `pi/durable/ledger.ts` strips the jq's last line and calls `round_error` without the append flag; the last line stays `envelope_error // round_error // empty`.
- `scripts/workflow-ledger-check:74` fingerprints `review-rounds.jq`, so every local ledger was replayed against the final jq.

## Decisions
### Keep T1/T2/D1/D2, make F rounds legacy-only
- Context: `pi/durable` and existing ledgers tag T1.
- Choice: no renaming; F1/F2/FD stay valid only in ledgers that already hold one.
- Rejected options: renaming rounds; migrating historical ledgers.
- Rationale: history and the durable consumer stay valid without rewrite.
- Consequences: a pre-change run waiting for its first F1 closes or goes `blocked`.

### Severity reuses `accepted_findings[].blocking`
- Context: severity was recorded but did not gate rounds.
- Choice: blocking = high severity, unmet AC, or a `BLOCK` verdict; no new outcome value.
- Consequences: a missing or legacy-shaped array is not clean.

### No ADR
- ADR-0019 governs the second review sample, which P1 does not change.

## Accepted Drift
- Original plan/spec: scope lists the machine, profile, prose and four smokes.
- Implemented reality: `workflow/durable-exports.md` T/D/F → T/D wording; `tests/guards-active-smoke.sh` (npm fixture also set through `NPM_CONFIG_PREFIX`, so an asdf node shim cannot shadow the stub) and `pi/extensions/__tests__/installed-extension-loader.test.ts` (follows the managed Pi installer launcher) repaired so `verify-agentic-infra core` passes on the maintainer machine; reviewed as round D2.
- Why accepted: wording coherence and a green required Check; the two test repairs were pre-existing failures that also reproduced on `main`.

## Validation Evidence
- `bash tests/workflow-event-smoke.sh`, `bash tests/ship-order-smoke.sh`, `bash tests/execution-quality-smoke.sh`, `bash tests/workflow-scaffold-smoke.sh`, `bash tests/workflow-docs-smoke.sh`
  - result: ok.
- `node --test tests/workflow-run-check.test.mjs`
  - result: 9 pass, 0 fail.
- `scripts/workflow-ledger-check --full`
  - result: ok=139 quarantined=12 stale=2 failed=0.
- `scripts/workflow-ledger-census baseline` / `diff`
  - result: no verdict flip; only this run's ledger grew.
- `scripts/workflow-context-budget`, `scripts/workflow-ref-linter`
  - result: 8 surfaces within ceiling; clean.
- `scripts/verify-agentic-infra core`
  - result: 35/35 after updating the sibling `pi-mobile` checkout to `main`, wiring the missing `PostToolUseFailure/Bash` hook in `~/.claude`, and the two test repairs.
- Review (high-risk), run under the new machine: plan adversary passes 1-5 on zai/glm-5.3 (READY on pass 5). T1 clean (Logic and Spec hunters, adversary GO WITH NOTES); D1 clean (fold of T1 notes); D2 clean (core test repairs; adversary `code-adv-d2b`).

## Follow-up State
- Remaining risks: `pi/durable/ledger.ts` probes without the append flag and `pi/durable/reviews.ts` still accepts FD/F1/F2, so a durable F1 passes the probe then is refused by the writer (fail-closed, dead-ends in reconcile); the profile predicate narrowing to T/D tags is unpinned by a smoke; the 50-line delta bar stays prose-only; in-flight ledgers paused at D2 findings awaiting F1 end `blocked`.
- Parking lot: loader test regex takes the first top-level `exec … --version` line and cannot capture quoted paths; its `which node` fallback can differ from the launcher's node.
- Superseded docs/specs: the T→F budget in `review-rounds.md`.
- Next links: P2 (review deduplication, ADR-0019), P3 (single contract), P4 (lighter plan), P5 (strict PLAN format).
