# Implemented: Calibrate all bounded Jev semantic profiles

## Metadata
- Archived: 2026-09-19
- Source plan: `PLAN.md` — Run reproducible live calibration for the twelve newly implemented Jev profiles
- Source plan SHA-256: `9d54309de5b4eeb27430ec07b5bc8139d063ab45300a3a512379498fd3494103`
- Status: IMPLEMENTED
- Commit / branch: uncommitted workspace on `main` at `eb1c043`
- Workflow initiative: `jev-profile-calibration`

## Outcome
- Added twelve sanitized frozen corpora with exactly twelve semantic cases per profile, deterministic label floors, safety cases, and claim preflight rejection.
- Added an explicit calibration CLI and dependency-free runner with three repetitions, concurrency one, zero retries, pre-dispatch 64k reservation, atomic mode-`0600` checkpoints, campaign-safe resume, and primitive-aware metrics.
- Executed 459 live `jev-1.13.0` provider attempts with 331,506 input tokens, 76,418 output tokens, zero provider errors, and measured input cost `$0.013923252`.
- `task-state-fallback` passes the frozen current thresholds. The other eleven profiles honestly remain `needs_tuning`; no authority, threshold, deterministic owner, or bundle promotion changed.
- Published campaign-bound per-profile reports and a summary under `workflow/runtime/jev-profile-calibration/`.

## Context
- `workflow/runtime/jev-profile-calibration/campaign.json`: immutable campaign contract and authoritative measured-or-reserved totals.
- `workflow/runtime/jev-profile-calibration/summary.json`: twelve independent verdicts and no bundle promotion verdict.
- `pi/extensions/lib/semantic-profile-calibration.mjs`: corpus validation, bounded provider wrapper, metrics, checkpointing, provenance, recompute, and verification.
- `tests/fixtures/jev-profiles/`: synthetic/sanitized calibration inputs; no private user or repository content was sent.

## Decisions
### Keep promotion profile-specific and manual
- Context: only one of twelve profiles passed every frozen quality and safety gate.
- Choice: retain all checked-in advisory/shadow authorities and thresholds.
- Rejected options: bundle promotion, same-corpus threshold tuning, and treating integration success as model quality.
- Rationale: target-domain evidence is profile-specific and the calibration corpus is not a held-out tuning set.
- Consequences: future changes require a new versioned holdout corpus and fresh evidence.

### Preserve fail-closed budget and resume evidence
- Context: a dispatched timeout or interrupted process can consume provider capacity without measured usage.
- Choice: charge and persist a 64k reservation before transport, retain it on failure, mark interrupted pending observations inconclusive without replay, and bind checkpoints/reports to one campaign.
- Rejected options: post-response-only accounting and unnamespaced checkpoints.
- Rationale: cost caps and resume integrity must survive unknown provider outcomes.
- Consequences: conservative reservations may reduce remaining budget after an ambiguous failure, by design.

### Separate collection and recompute provenance
- Context: metric-code hardening occurred after the live observations were collected.
- Choice: preserve checkpoint-backed `collection_identity`, record the historical CLI fingerprint as unavailable, and bind current metric code through `recompute_identity`.
- Rejected options: rewriting collection fingerprints with current source hashes.
- Rationale: recomputation must not claim newer code produced older observations.
- Consequences: verification checks both identities according to their distinct roles.

## Accepted Drift
- Original plan/spec: reports bind one runtime/harness identity.
- Implemented reality: reports bind separate collection and recompute identities because review-driven metric and safety hardening followed live collection.
- Why accepted: the split is more truthful and preserves reproducibility without repeating paid calls.

## Validation Evidence
- `bun test pi/extensions/__tests__/semantic-profile-calibration.test.ts pi/extensions/__tests__/semantic-profiles.test.ts`: 25/25 tests passed in final review.
- `scripts/jev-profile-calibrate verify-reports --all`: 12/12 reports complete and verified.
- `scripts/verify-agentic-infra core`: 21/21 checks passed; Pi suite 299/299.
- `scripts/router-eval`: 212/212 cases passed.
- `scripts/jev-shadow health`: enforced TypeSafe mode, pinned `jev-1.13.0`; credential intentionally absent from the validation subprocess.
- `git diff --check`: passed.
- Final code review found and fixed aggregate calibration acceptance drifting from per-response runtime thresholds, then recomputed and reverified all twelve reports.
- Final route review bound the Pi authority adapter into the promotion runtime fingerprint and regenerated its live evidence.
- `pi/extensions/pi-mobile-bridge.ts`: remained untracked and byte-identical (`b7570750e76c7f37e409b2c4de6374cb6b5137519681f790121892f00f05e257`).

## Follow-up State
- Remaining risks: synthetic English-first corpora do not establish production, multilingual, or private-domain quality.
- Parking lot: tune questions/prompts rather than thresholds first, then evaluate each candidate against a new held-out corpus.
- Superseded docs/specs: none.
- Next links: `workflow/runtime/jev-profile-calibration/README.md`, `workflow/semantic-profiles.md`.
