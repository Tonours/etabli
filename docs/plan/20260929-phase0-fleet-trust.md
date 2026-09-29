# Implemented: Agent fleet & trust Phase 0 — instrumentation and write authority

## Metadata
- Archived: 2026-09-29
- Source plan: `PLAN.md` — Phase 0 de la roadmap « Agent fleet & trust élevé » v2 (slices 1-5 etabli + handoff S6 dotfiles)
- Source plan SHA-256: `c6943ad31e57e69bd2d425851918058424a5344628e989cfb5899f0f20217892`
- Status: IMPLEMENTED
- Commit / branch: `feat/phase0-fleet-trust` 226a44c..7f8471d (10 commits, not pushed)
- Workflow initiative: `phase0-fleet-trust` (ledger 22 events)

## Outcome
- `scripts/workflow-lease`: per-(repo, worktree) TTL lease, token-checked renew/release, expiry-only takeover with mandatory history trace, foreign-host refusal while valid, canonical (realpath, no auto-mkdir) scope hashing, lockf/flock/shlock locking with the shlock mutation running in the lock-holding process. ADR-0028 (single integrator = Mac mini; two topologies; bounded acquisition-arbitration guarantee). Quick-card/spec/contract-details now reference the mechanism instead of "protocol, not an OS lock".
- `correction` ledger event (vocabulary synced across bash/jq/mjs + events.md): emitted on later interactive prompts while the primary active ledger is non-terminal. Pi subscribes `input` (interactive only, steering covered, extension/rpc excluded), session id from `ctx.sessionManager.getSessionId()` (abstains without one); Claude `UserPromptSubmit` hook. Both harnesses append through the locked `workflow-event append` CLI. Per-session count state under `.workflow/correction-state/` (one file per session, no shared-file RMW); prompt text never persisted (sha256 + chars).
- Guard journal (`workflow/runtime/guard-journal.mjs`): every wired denial (no-comments shared+claude, plan-ready, plan-commit, check-freeze, read-only-agent; rtk bypass excluded) appends filtered `{ts, host, harness, guard, pattern, target, tool}` lines to `.workflow/guard-journal/`, best-effort, never blocks the deny.
- `blocked.reason` enum append-only (10 values incl. `ledger_recovery`; free-text stays valid in v2 and legacy history; census 133 ledgers, zero flips); `human_checkpoint.consent_class`; Claude `Notification` classifier on `notification_type` (permission_prompt/idle_prompt mapped, unknown abstains).
- `workflow-ship-metrics report`: on-demand KPI join (registry rows by file mtime with available/partial/unreadable/zero-observed states, ledgers incl. corrections/blocked-by-reason/checkpoints/ship ci_state, guard journal, optional herdr history with per-(host,pane) seq-hole exclusion and window-clipped intervals); accepted merges, review minutes, reverts J+7, cost named missing until receipts exist. No metric event types reintroduced (T2/T3 lesson enforced).

## Context
- PRÉALABLE slice 5 (why metric types were retired): additions 091bcac/ea00192/6cc67d4; removals c148b72 (T2, plan `docs/plan/20260926-minimal-core-t2.md` SHA a7ec70c…) and 4d6fd5e (T3, plan `docs/plan/20260926-minimal-core-t3.md` SHA 82be964…); ADR-0013 (13 events in 2 days, ten-outcome bar never cleared), ADR-0019 (measure ambient tooling before cutting passes). Lesson: compute on demand from real sources; name missing sources; no emission-side metric types; no per-validate integrity cost.
- The last independent full pass (F2, codex/gpt-6-astra) ended BLOCK; all five findings were folded in 7f8471d and pinned by smokes. A fresh independent pass at merge time is recommended before any push.

## Decisions
### Gate 0 separated from plan completion (adversary F12)
- Context: roadmap Gate 0 ("ADR merged", ≥1 week real traffic) depends on receipts outside this repo.
- Choice: this plan's archive covers the Etabli delivery only; Gate 0 stays a phase-level criterion tracked in the roadmap, pending (observation window, dotfiles herdr history, ADR integration/push decision).
- Rejected options: redefining "merged" as "committed locally" inside the plan AC.
- Rationale: a plan must not close criteria it cannot evidence.

### Envelope 2 kept; "schema v3" = detail conventions revision
- Context: roadmap says "schéma v3"; bumping the envelope would touch three validator lists plus adapter hot paths.
- Choice: enum/consent_class/correction inside envelope 2, following the append-only strictness precedent (`appended_adversary_pass`); history stays lenient.
- Rationale: minimal surface; 133-ledger census proves zero flips.

### Claude/Pi correction appends go through the locked CLI
- Context: `appendLedgerEvent` is a raw appendFileSync; only Pi/Codex extensions are the documented hot-path exception; the adversary demonstrated a completed→correction interleave invalidating the ledger.
- Choice: both new hooks spawn `scripts/workflow-event append` (locked, terminal-checked); the pre-existing route_decided hot path is unchanged (out of scope).
- Rationale: a correction is one append per user prompt — latency is irrelevant; correctness is not.

### spec-map ceiling raise 29 875 → 30 120
- Context: the guard-journal contract line in contract-details exceeded the frozen ceiling by 213 chars.
- Choice: reviewed budget diff with plan Decision Log rationale; wording already compacted first.
- Rationale: documented growth path; `--ratchet` remains the only lowering mechanism.

## Accepted Drift
- Original plan/spec: ledger-auto-emit shared session state as one `correction-state.json`.
- Implemented reality: per-session files under `.workflow/correction-state/` (hunter finding: unlocked RMW race between concurrent sessions).
- Why accepted: eliminates the race without adding locking; same semantics.
- Original plan/spec: S2 rollback left as "implementation decision".
- Implemented reality: decided at plan stage — removal goes through the three retired lists (T3 mechanism).
- Why accepted: no open question left in a READY plan.

## Validation Evidence
- command: `scripts/verify-agentic-infra core`
  - result: 28/29 PASS (sole failure `pi-audit`: pre-existing transitive undici advisory GHSA-3wwx-pv8p-q78v, no dependency touched by this branch)
- command: `bun test pi/extensions/__tests__/` (+ `bash tests/pi-typecheck-smoke.sh`)
  - result: 355/355 pass; typecheck ok
- command: `bash tests/workflow-lease-smoke.sh` (also with `WORKFLOW_LEASE_LOCK_BACKEND=shlock`)
  - result: PASS T1-T10, R1-R2 on both backends
- command: `bash tests/{guard-journal,workflow-event,ledger-auto-emit,claude-hooks,workflow-ship-metrics-report}-smoke.sh`
  - result: all PASS
- command: `scripts/workflow-ledger-census baseline|diff`
  - result: 133 ledgers (121 OK / 12 QUAR), zero verdict flips
- command: `scripts/validate-adrs`
  - result: ok, 28 records
- command: `scripts/deploy-agent-workflow --apply` + `scripts/claude-hooks-merge` (both Claude roots) + `scripts/claude-hooks-check`
  - result: all fragment hooks wired (UserPromptSubmit, Notification included)
- reviews: Logic hunter T1 (pi-child fresh) PROCEED/5 folded; Logic hunter T2 PROCEED/2 folded; D1 delta clean; Spec F1 (parent) 1 folded; code-diff adversary (codex/gpt-6-astra, cross-family, provenance on ledger) BLOCK/5 folded; F2 adversary BLOCK/5 folded — all folds test-pinned

## Follow-up State
- Remaining risks: last independent pass ended BLOCK→folded (fresh pass advised before merge/push); Claude notification_type payload values verified against docs only, real-event confirmation lands in the Gate 0 window; lease adoption is procedural until Phase 3 wires workers.
- Parking lot: Pi `before_agent_start` route_decided hot path keeps the documented appendFileSync exception (pre-existing, out of scope); ADR-0028's force-with-lease guard note awaits the Phase 2.5 envelopes.
- Superseded docs/specs: workflow/agent-quick-card.md "protocol, not an OS lock" wording; events.md blocked/human_checkpoint rows (v3 conventions); `tests/fixtures/workflow-events-v2.tsv` blocked row now enum-typed.
- Next links: S6 session dotfiles dédiée (handoff complet dans le plan source §Slice 6 — plugin agent-status-history, jq parsing, seq-gap reader, plugins.json relink) ; fenêtre d'observation ≥7 jours ; Gate 0 (critère de phase) ; Phase 1 pilote.
