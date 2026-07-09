# Implemented: Hardened agent workflows and bounded LLM loops

## Metadata
- Archived: 2026-07-09
- Source plan: complete workflow/code-review hardening and LLM loop practices
- Status: IMPLEMENTED
- Branch: main working tree (not committed or pushed)

## Outcome
- Restored deterministic CI parity with a grouped local runner shared by GitHub Actions.
- Made full-page capture bounded, process-owned, path-contained, atomic, and testable.
- Replaced copied skill arrays with a Bash-3-compatible catalog and extended the lock to 20 maintained skills.
- Reduced Pi router logic to a typed adapter over the shared classifier and consolidated golden prompts into one 29-case dataset.
- Added bounded loop-pattern selection, budgets, reset/escalation fields, and restartable handoff rules.
- Versioned workflow events, added typed details and completion profiles, rejected missing ledgers by default, and made terminal ordering enforceable.
- Corrected retrospective negation handling, measured/unmeasured outcome reporting, capability freshness, and source-conflict detection.
- Reduced always-read instructions to 1,859 estimated tokens (19.66% of the 9,455 baseline).
- Made `scripts/install.sh` a five-line stable entry point and moved implementation detail behind `scripts/lib/`.

## Context
- GitHub run `28899546716` exposed a stale skill lock and instruction-budget overrun.
- The original routers contained parallel classifier logic; local metrics had 25 terminal ledgers and zero measured outcomes.
- The new MengTo capture/skill work was preserved and hardened rather than reverted.

## Decisions
### Prefer one catalog and one golden dataset
- Choice: use `workflow/runtime/skill-surface.tsv` and `tests/router-evals/core.json` as machine-readable ownership surfaces.
- Rejected: synchronized copied arrays and prompt lists.
- Consequence: installer/deployer/repair tests and both router adapters now fail together on drift.

### Make completion evidence structural
- Choice: require versioned envelopes, event details, terminal ordering, two adversary modes, post-change validation, review, simplification, outcome, archive, and plan cleanup in the autonomous profile.
- Rejected: prose-only completion and accepting absent ledgers as success.

### Bound advanced loop patterns
- Choice: direct or localization/repair/validation first; ReAct, self-refine, evaluator, parallel, and tree search only behind explicit need, verifier, cap, and permission gates.
- Rejected: a new general-purpose orchestration runtime.

## Accepted Drift
- Live Playwright/ffmpeg capture was not run because Playwright was unavailable in this workspace. The realistic HTML fixture and pure helper tests passed; the live leg remains explicitly blocked/opt-in.
- Fresh-context delegation was not authorized. A supervised same-model code review plus adversarial diff pass returned GO WITH NOTES; it found and fixed zero-step parsing, lock-write masking, post-terminal events, CI Bun coupling, and Neovim lock mutation.
- GitHub status on an exact pushed SHA was not checked because no commit or push was authorized.

## Validation Evidence
- `scripts/verify-agentic-infra all`: PASS.
- Pi: 186 tests passed; 0 failed.
- Router eval: 29/29, accuracy 1, alignment 1, zero safety/research misses.
- Skill lock: 20 hashes verified.
- Capture: 4 pure tests plus deterministic fixture smoke passed; live leg skipped explicitly.
- Efficiency: 1,859/9,455 estimated tokens; strict 20% target passed; zero declared source conflicts.
- Metrics: 25 historical terminal runs labelled unmeasured; missing tokens do not produce an efficiency ratio.
- `git diff --check`: PASS.

## Follow-up State
- Remaining risks: the extracted installer implementation is still large internally; further decomposition should be behavior-preserving and driven by a concrete change, not line count alone.
- Parking lot: opt-in repeated live-model route trials and the live browser capture fixture when runtime/budget are available.
- Next links: `workflow/loop-patterns.md`, `workflow/events.md`, `workflow/runtime/source-ownership.tsv`.
