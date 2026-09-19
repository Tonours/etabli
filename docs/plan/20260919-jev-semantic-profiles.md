# Implemented: Bounded Jev semantic profiles across Etabli

## Metadata
- Archived: 2026-09-19
- Source plan: `PLAN.md` — Generalize bounded Jev judgments across Etabli
- Source plan SHA-256: `802b554f7cd211d87422994438f68ec50238c011c57f44ff135d95383913bd9e`
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main` at `eb1c043`
- Workflow initiative: `jev-use-cases`

## Outcome
- Added one validated catalog for twelve opt-in Jev seams, each with typed questions, bounded state, explicit uncertainty, deterministic ownership, and shadow/advisory authority.
- Added a dependency-free runtime and `jev-judge` CLI with exact live-egress consent, secret and size rejection, prompt-free receipts, fail-open outcomes, installer ownership, and link verification.
- Added two-stage skill suggestion over all 81 repository catalog entries, including no-match and namespaced-skill handling.
- Composed semantic claim/evidence judgment with the canonical structural checker, descriptor-safe input, mutation sealing, state projection, and mandatory canonical claim selection.
- Integrated profile contracts into the matching workflow and Pi skill documentation without changing the existing promoted workflow router or Obvault ownership.

## Context
- The initial profile implementation left the promoted route unchanged. Final integration hardening later added explicit no-store transport, locked its enforced mode, bound the Pi authority adapter into the route fingerprint, and regenerated the 30-case route evidence.
- `pi/extensions/pi-mobile-bridge.ts` was unrelated user work; it remained untracked and byte-for-byte unchanged at SHA-256 `b7570750e76c7f37e409b2c4de6374cb6b5137519681f790121892f00f05e257`.
- No provider credential was present, so validation exercised contracts with synthetic providers and made no paid/live TypeSafe call.

## Decisions
### Keep deterministic code authoritative
- Context: Jev supplies semantic probabilities but must not own permission, mutation, arithmetic, routing guards, or external actions.
- Choice: expose only shadow/advisory profiles and retain deterministic owners in the policy.
- Rejected options: automatic provider calls, direct action authority, and replacing the promoted workflow route.
- Rationale: semantic judgment remains useful without weakening reproducibility or write control.
- Consequences: every profile requires a separate live corpus and promotion artifact before broader authority.

### Minimize provider state by schema projection
- Context: profile inputs can contain private prompts, evidence, and local filesystem metadata.
- Choice: require exact `allowProviderEgress: true`, validate and project declared fields, reject secret-like content, and keep raw state out of receipts.
- Rejected options: forwarding caller objects unchanged or trusting truthy consent.
- Rationale: the provider receives only the smallest declared state.
- Consequences: dynamic skill descriptions are carried in bounded typed question instructions instead of undeclared state.

### Preserve structural claim provenance
- Context: a caller-supplied boolean could otherwise forge successful deterministic validation.
- Choice: derive claim state through `scripts/claim-evidence-check`, seal it with an object fingerprint, and reject post-check mutation before provider I/O.
- Rejected options: accepting `structural_valid: true` from generic JSON or rerunning the checker on loosely related state.
- Rationale: semantic judgment cannot upgrade a missing or structurally invalid source.
- Consequences: claim evaluation has a dedicated CLI command and mandatory canonical claim index.

## Accepted Drift
- Original plan/spec: the claim/evidence adapter could have been implemented directly in the existing structural checker.
- Implemented reality: a focused `semantic-claim-evidence.mjs` adapter snapshots the claim file, invokes the checker, reads bounded evidence, and seals the resulting state.
- Why accepted: it preserves the checker as deterministic source of truth without adding provider logic to that script.

- Original plan/spec: skill stage two considered carrying a `finalists` array in provider state.
- Implemented reality: state remains limited to request and stage; each `fits_N` question carries the corresponding bounded description.
- Why accepted: this preserves the information needed for judgment while minimizing state and avoiding nested schema expansion.

## Validation Evidence
- `scripts/verify-agentic-infra core`:
  - 21/21 checks passed; 288 Pi tests and 845 assertions passed; typecheck, audit, skill lock, Jev profile smoke, and existing Jev shadow smoke passed.
- `scripts/router-eval`:
  - 212/212 cases passed with accuracy and alignment rate 1.0.
- `bun test pi/extensions/__tests__/semantic-profiles.test.ts`:
  - 13/13 tests and 83 assertions passed after the final skill-description correction.
- `tests/jev-judge-smoke.sh`, `tests/agentic-infra-manifest-smoke.sh`, and `git diff --check`:
  - passed.
- `scripts/jev-shadow health`:
  - existing route reports `ok: true`, `mode: enforced`, provider `typesafe`, model `jev-1.13.0`; credential absent.
- Final review findings were corrected before integration: calibration acceptance now matches per-response runtime thresholds, and the route promotion fingerprint includes the Pi authority adapter.

## Follow-up State
- Remaining risks: synthetic tests prove contract behavior, not live Jev quality; every new profile stays opt-in shadow/advisory until dedicated calibration.
- Parking lot: build per-profile live corpora and promotion evidence only when explicitly authorized and a provider credential is available.
- Superseded docs/specs: none.
- Known unrelated baseline: `tests/workflow-docs-smoke.sh` reports unchanged `workflow/spec.md` at 221 lines against its 220-line cap.
- Next links: `workflow/semantic-profiles.md`, `workflow/runtime/semantic-profile-policy.json`, and `scripts/jev-judge`.
