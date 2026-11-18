# Implemented: explicit Claude usage scope and leaner session habits

## Metadata
- Archived: 2026-11-09
- Source plan: `PLAN.md` - implement six Claude Code token-efficiency recommendations
- Source plan SHA-256: `26eaf9bf20439a08c9a0edb0032972e1dde0e409fa52103deaeb1709fa286ec1`
- Status: IMPLEMENTED
- Commit / branch: `perf/claude-token-usage`, base `07927127105522cd34111a35c9576aae4746a106`
- Workflow initiative: claude-token-usage

## Outcome
- Existing review usage records now label native cumulative scope, possibly restored balances, reported modelUsage coverage, is_error and per-model costBasis. Counter categories stay separate; no extra thinking amount, fabricated zero or per-caller attribution.
- Statusline adds a native session USD estimate while retaining last-parent labels and unknown child token coverage. Native precision, including tiny positive values, is retained; no verified whole-tree/billing claim.
- The existing settings writer admits promptSuggestionEnabled and awaySummaryEnabled booleans; the shared fragment sets both false. Managed values win at sync, environment overrides are preserved, and compaction/model/effort/permission defaults are untouched.
- Cold orchestration guidance names direct/fresh/fork context choices, bounded briefs, independent reviewers, worker continuation and avoiding duplicate work. Cache/context recipes use existing handoff, clear/compact, scoped reads and deferred tools.
- Remote Control recipes distinguish attaching an interactive session, server-recorded continuation and intentionally new sessions; no wrapper, server, service or implicit fallback is added.
- Retain the sourced research note with its preimplementation snapshot and limits.

## Decisions
- Reuse weekly review logging instead of adding a new usage CLI/collector without a demonstrated weekly consumer. The preliminary fixture exercise proved an arithmetic pitfall, not a need for another subsystem.
- Never sum overlapping resumed/copied/forked cumulative snapshots. Without an opening balance, new consumption is unknown; native model totals include reported children according to their documented scope, not independent completeness proof.
- The owner's request implements optional UI-request defaults, while preserving quality-critical review choices and existing effect authority. Native environment overrides can re-enable them; local /config toggles alone are overwritten on the next sync.
- Recipes and documentation are deployed instructions, not enforcement of native runtime choices or proof of mobile/account eligibility.

## Accepted Drift
- P1 plan challenge removed the proposed standalone accounting CLI and unverifiable snapshot delta. P2 approved the simpler existing-seam plan, including lifecycle and provenance clarifications.
- T1 Spec gaps were filled with named native commands, explicit syntax-only Remote Control limits, a synthetic cumulative control and stronger attack regressions. The dry-run already proved scalar drift and gained an explicit WOULD_SYNC assertion.
- T2 Spec's sole low note clarified that error/zero, missing, multi-model, cumulative and malformed variants are synthetic controls derived from a real native success capture. No observed child execution or billing calibration is claimed.

## Validation Evidence
- `node --test tests/surfaces.test.mjs`: baseline 44/44; new assertions red before implementation; final focused 48/48, including type refusal, adjacent privileged keys, local secrets/env preservation, dry-run, idempotence, backups and private install.
- `bash tests/claude-statusline-smoke.sh`: pass, including zero, missing/invalid/non-finite values, exact delimiters and tiny positives.
- `bash tests/pr-review-flow-smoke.sh --usage`: 13/13 controls; real native success envelope plus labeled synthetic variants. Existing full-flow prefix and gate behavior preserved.
- Deploy, Claude skill-load, entry-chain and workflow contract smoke checks: pass; entry chain remains 401/405 lines.
- `scripts/verify-agentic-infra full`: full-v1 46/46 before documentation/test-only folds; final archive-inclusive run remains a delivery gate, reported separately after this immutable record.
- Mutation: 0 survived of 2 generated operators, no invalid/denied/timeout outcomes in the successful run. Only statusline had generated mutable operators; whitelist strings and embedded jq rely on positive/negative controls. Four production/config patch sections remain byte-identical across T1/T2. Initial baseline denied the fixture's home-cache mktemp; one corrected run allowed that known fixture directory and passed.
- `replay: unavailable` (bounded selected-vault lookup found no reachable frozen escaped case; semantic lookup unavailable). No hunter prompt/model/inspection invocation changed; only advisory formatting in its shared library.
- Plan P1 CHALLENGED then P2 READY; T1 Logic/Threat GO with Spec process gaps folded; T2 Logic/Threat GO, Spec complete/provenance clarified, closing code adversary GO. Requested/effective reviewer model Claude Opus5.5 via native T3, Anthropic, distinct from OpenAI authors; requested high effort, effective effort not independently exposed. All hunter templates inline, full deciding-code/lens and six Threat tables retained; final lead GO WITH NOTES.
- Reviewed cumulative patch SHA-256: `9242d9728a8c249c0ca5c18b11db335688ae3525ef56c514bfeaf9fd656f9c8f`, base `07927127`. No production/source changes after the clean close. Scoped hunts were not certified as council phase-A equivalence, so no reuse file was packaged.
- `simplify: clean`; `quality: pass` (code-quality with existing JavaScript normalizer, scalar whitelist/atomic writer and sibling settings sync).

## Follow-up State
- Source delivery only; no deployment, CLI upgrade, account setting or Remote Control connection was performed. Existing loaded sessions are not rewritten.
- Real task token/cost/quota savings, mobile/account eligibility and IDE/SDK effective settings remain unmeasured or untested. Native labels and fixture controls are not evidence of such gains.
- Keep the feature worktree while its PR is open; original main checkout and its owned untracked research copy are preserved. Archive cleanup removes only this run's root PLAN.md after the hash gate.
