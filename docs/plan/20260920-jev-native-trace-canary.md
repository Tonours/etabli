# Implemented: native Pi trace correlation and Jev diagnosis canary

## Metadata
- Archived: 2026-09-20
- Source plan: `PLAN.md` — Bind a Pi session to one workflow run and exercise the Jev-first diagnosis seam on sanitized evidence.
- Source plan SHA-256: `4fd7918137770dec8fa77b81f5885ef9ea17a13d2105b32e9d3e465583578fb1`
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main` at `3cc4b08`
- Workflow initiative: `jev-real-trace-canary`

## Outcome
- Added an auto-discovered Pi lifecycle extension that emits a domain-separated correlation fingerprint over the private session id, requested run, and immutable ledger genesis without persisting those identifiers in cleartext.
- Added fail-closed native correlation to the trace analyzer while preserving legacy `explicit_unverified` observations and Claude compatibility.
- Added a privacy-safe Jev diagnosis canary. Offline mode proves preparation; explicit-live mode uses Jev without persisting a receipt and safely abstains when the credential is absent.
- Jev is now the required semantic diagnostician for this bounded canary, while deterministic code retains eligibility, privacy, permission, mutation, promotion, and rollback authority.

## Context
- `pi/extensions/workflow-run-binding.ts`: emits one binding per active run from `tool_result` and `agent_settled` without breaking the Pi lifecycle on metadata failure.
- `scripts/lib/pi-run-binding.mjs`: shared canonical producer/verifier for the correlation fingerprint.
- `scripts/lib/harness-trace-retrospect.mjs`: validates full lineage, attributes only the requested ledger window, and accepts a post-terminal result for an in-window call.
- `scripts/jev-judge`: exposes a fixed aggregate canary output that omits paths, run/session ids, fingerprints, raw prompts, responses, and traces.

## Decisions
### Treat native binding as correlation, not authentication
- Context: an unkeyed local hash can detect mismatch and accidental replay but cannot establish malicious-file authenticity.
- Choice: name the state `native_correlated` and fail closed on current-window mismatch, malformed binding, or duplicate binding.
- Rejected options: claim native verification; persist plaintext identifiers; add encryption without a new trust boundary.
- Rationale: the label and guarantees remain falsifiable and privacy-bounded.
- Consequences: a future authenticated provenance layer would require a separate threat model and key boundary.

### Make Jev first-class inside a bounded diagnostic plane
- Context: Jev previously had a diagnostic profile but no native-correlated canary path.
- Choice: require a complete native Pi observation before preparing or calling the `self-improvement-diagnosis` profile.
- Rejected options: deterministic semantic fallback; automatic mutation/promotion; using an unbound trace for the canary.
- Rationale: Jev produces the semantic judgment without weakening operational controls.
- Consequences: integration is proven locally; provider quality remains unmeasured until a real corpus and credential are authorized.

## Accepted Drift
- Original plan/spec: binding emission could have been added to the promoted workflow router.
- Implemented reality: binding emission lives in a separate auto-discovered extension.
- Why accepted: this preserves the promoted router manifest and keeps the new lifecycle responsibility isolated.

## Validation Evidence
- `tests/harness-trace-retrospect-smoke.sh`, `tests/jev-judge-smoke.sh`, focused Bun tests, `tests/pi-typecheck-smoke.sh`, and `git diff --check`:
  - passed; focused Bun suite reported 19 tests and 140 assertions.
- `scripts/verify-agentic-infra core`:
  - 22/22 checks passed; 306 Pi tests with 958 assertions; router evaluation 212/212.
- `scripts/workflow-context-budget`:
  - all seven surfaces remained within ceiling.
- Cumulative isolated review of patch `0448ccac171c12c6224f4139cb9cdc5f8dfd61542983326f63d77f3c3a8394b8`:
  - Logic Hunter: `GO`, no findings.
  - Spec Hunter: `GO`, no findings.
  - Cross-model adversary: runtime-attested `xai/grok-4.3`; its final claimed post-terminal incompleteness was rejected because the pinned code updates `windowResults` unconditionally and the regression/full suite passed.
- Canary evidence:
  - offline output: `prepared`, `native_correlated`, `complete`, diagnostic authority.
  - explicit-live output without credential: `abstain`, reason `missing_api_key`, provider `typesafe-system-one`, model `jev-1.13.0`.

## Follow-up State
- Remaining risks: Jev quality and abstention behavior are unmeasured on a versioned real-format corpus; native correlation is not authentication.
- Parking lot: authorize a private provider-backed corpus run, calibrate held-in/held-out diagnosis quality, and design authenticated provenance only if the threat model requires it.
- Superseded docs/specs: the native-binding parking-lot item in `docs/plan/20260920-jev-first-diagnosis.md` is completed by this archive.
- Next links: `workflow/trace-self-improvement.md`, `docs/plan/20260920-jev-first-diagnosis.md`, `workflow/runtime/jev-profile-calibration/README.md`.
