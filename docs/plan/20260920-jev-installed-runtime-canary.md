# Implemented: Installed Pi runtime and native Jev diagnosis canary

## Metadata
- Archived: 2026-09-20
- Source plan: `PLAN.md` — repair the installed Pi extension loader and prove a native-correlated Jev canary input
- Source plan SHA-256: `e071d0d8361b47b7f1753f2610d7c6fc32cea297e58b445617c1de5ae78274db`
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree on `main`
- Workflow initiative: `jev-installed-runtime-canary`

## Outcome
- The installed Pi 0.85.1 loader now resolves the repository-owned extension graph through managed `~/.pi/scripts` and `~/.pi/workflow` links.
- Jev owns the typed `self-improvement-diagnosis` judgment boundary as a first-class diagnostic actor; mutation, promotion, and deployment remain outside its authority.
- A real private Pi episode produced one route, one decision receipt, and one native workflow binding. The analyzer accepted it as complete without exposing raw trace content.
- The offline Jev canary is prepared. Provider-backed quality remains untested because the TypeSafe credential is absent; no TypeSafe call was made.

## Context
- The original failure only reproduced through Pi's installed Node/jiti loader; plain Bun imports canonicalized symlinks differently and were insufficient evidence.
- `workflow-router.ts` is promotion-fingerprinted, so the runtime repair preserves that source and fixes the installed layout around it.
- The native binding occurs after the routed episode. Correlation therefore uses the latest router row preceding the matching binding and cross-checks the corresponding decision receipt.

## Decisions
### Preserve the calibrated router and repair its installed roots
- Context: editing the calibrated router invalidated its Jev promotion fingerprint.
- Choice: manage the canonical scripts and workflow roots through the existing recoverable link reconciler, while keeping the new binding extension behind realpath-backed adapters.
- Rejected options: copy policy modules into the extension tree; rely on source-checkout-only imports; alter the calibrated router.
- Rationale: canonical ownership and promotion evidence remain intact while the real installed loader works.
- Consequences: deploy and link-check tooling now owns two additional Pi paths.

### Make route correlation binding-relative and lifecycle-aware
- Context: the router row can precede the ledger time window, and a READY plan legitimately changes the runtime route from `plan-implement` to `implement`.
- Choice: select the latest route before the native binding, require any intervening receipt to agree, and permit only `plan-implement` to `implement` when the latest ledger plan status is `READY`.
- Rejected options: accept any route in the file; trust the prompt; allow arbitrary route aliases.
- Rationale: the rule matches the observed Pi lifecycle and fails closed for missing, stale, or conflicting evidence.
- Consequences: missing, DRAFT, CHALLENGED, reverse, and unrelated transitions remain unavailable.

### Keep raw canary evidence private
- Context: Pi session content and run identifiers are not suitable for the public repository.
- Choice: retain raw sessions and the decision-ledger projection only under ignored `.workflow` storage and publish aggregate evidence.
- Rejected options: commit sanitized-looking copies; cite private paths or identifiers in durable docs.
- Rationale: aggregate proof is sufficient for runtime and boundary validation.
- Consequences: future audits must regenerate or inspect the local private evidence in place.

## Accepted Drift
- Original plan/spec: repair two proven dependency edges with adapters.
- Implemented reality: the calibrated router stayed byte-identical and two canonical installed roots became managed links; only the uncalibrated binding path uses new adapters.
- Why accepted: this preserves the existing promotion fingerprint and reproduces the real Pi loader semantics.
- Original plan/spec: produce one functional Pi canary.
- Implemented reality: an interim canary was superseded and a second was rejected for route mismatch before the third and final canary became authoritative.
- Why accepted: each failed candidate exposed a real contract gap; neither invalid trace is used as final evidence, and the operational budget explicitly records all three generations.

## Validation Evidence
- `scripts/verify-agentic-infra core`:
  - result: 22/22 checks passed.
- `bun test pi/extensions/__tests__/`:
  - result: 307 tests passed, 0 failed.
- Active Pi 0.85.1 Node/jiti loader regression:
  - result: pinned baseline of two load failures reduced to zero for eight repository-owned entrypoints; separate host aggregate loaded ten of ten active entrypoints.
- `tests/harness-trace-retrospect-smoke.sh`:
  - result: passed, including real Pi metadata, route/receipt conflict, and READY lifecycle cases.
- Final private episode aggregate:
  - result: eight rows, one `implement` route, one router receipt, one binding, native correlation complete, no reason code, and no tracked raw artifact.
- `scripts/jev-judge health` and offline canary:
  - result: provider `typesafe-system-one`, model `jev-1.13.0`, credential absent, live disabled by default, offline preparation successful.
- Final reviews:
  - result: Logic GO, Spec GO, and the single authorized cross-model code-diff adversary GO.
- Managed-link assertions and `git diff --check`:
  - result: both new links resolve to this checkout and the diff is clean. The broad link checker still reports six unrelated pre-existing TypeSafe/ADR warnings.

## Follow-up State
- Remaining risks: Jev diagnosis accuracy and calibration are not provider-verified; the current result proves runtime integration and typed diagnostic authority only.
- Parking lot: run the bounded provider-backed corpus campaign after explicit credential availability and authorization.
- Superseded docs/specs: none; earlier Jev diagnosis and native trace archives remain the preceding implementation records.
- Next links: `docs/plan/20260920-jev-first-diagnosis.md`, `docs/plan/20260920-jev-native-trace-canary.md`, and `workflow/trace-self-improvement.md`.
