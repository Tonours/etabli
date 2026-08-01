# Implemented: Reduce repeated Pi and Claude harness hot-path work

## Metadata
- Archived: 2026-08-01
- Source plan: `PLAN.md`
- Subject: Remove repeated Pi/Claude harness filesystem scans and false ledger blockers
- Source plan SHA-256: `dd7e22a5e0c06a90860d474338dae7357c893c56ba40975ef733d62f985cb510`
- Status: IMPLEMENTED
- Commit / branch: main (commit created by this change)

## Outcome
- Short-circuited the shared mutation guard before PLAN.md/ledger work for irrelevant Pi and Claude tools.
- Composed Claude's plan-commit decision into the existing plan-ready PreToolUse process, removing the second Bash hook process while preserving the standalone wrapper.
- Made active ledger selection pointer-first and strict: selected ledgers are validated, pointer slugs are confined, symlinked ledgers are rejected, and historical post-terminal invalid records do not block valid legacy fallback selection.
- Limited Pi runtime receipts to explicit validation commands and reused already-inspected ledger events.
- Added pointer revalidation before append, non-overwriting activation, negative fixtures, and a benchmark registered in the full infrastructure profile.

## Context
- Mac mini Pi session `~/.pi/agent/sessions/--Volumes-Crucial-work-etabli--/2026-08-01T07-45-00-130Z_019fbc48-90e2-7408-be0b-ce07475ab666.jsonl`: 572 tool calls over about 6h40, including 172 reads, 137 Bash calls, and repeated Task* continuation activity.
- Mac mini `/Volumes/Crucial/work/etabli/.workflow`: 50 ledgers, 1,215 events, about 1.4 MB, and one historical `etabli--proved` ledger invalid only because events followed a terminal event.
- Before the change, pointer selection parsed the whole ledger directory; the synthetic after-check inspected 1 ledger with a pointer and 53 in the no-pointer compatibility fallback.
- Dynamic obvault routing was deliberately not changed: direct execution measured about 200 ms per prompt on the Mac mini, while the current SSH wrapper fails fast because `node` is absent from that PATH.

## Decisions
### Pointer-first authority
- Context: historical ledgers are immutable and may contain legacy post-terminal compatibility events.
- Choice: inspect only the explicit active pointer when present; retain a strict valid-only legacy fallback when absent; reject malformed/traversal/symlinked selected paths.
- Rejected options: delete or rewrite old `.workflow` ledgers; claim an OS-level lock.
- Rationale: bounds normal active-run work without weakening selected-ledger validation.
- Consequences: a receipt-backed run must use the existing explicit `workflow-event activate` path; the residual post-check TOCTOU remains a documented single-writer/proxy limitation.

### Validation-only receipts
- Context: Pi emitted a receipt for every successful Bash result, including `ls` and `git status`.
- Choice: allow only explicit validation commands and reject shell suffixes, path traversal, and mutating lookalikes.
- Rejected options: infer validation from broad words such as `test`, `check`, or `build` anywhere in arbitrary arguments.
- Rationale: avoid filesystem scans and false evidence while retaining common test/check/verify runners.
- Consequences: custom validation commands outside the allowlist are not receipt-covered and remain an explicit telemetry gap.

### Claude hook composition
- Context: Bash had separate `plan-ready-guard` and `plan-commit-guard` processes.
- Choice: run both decisions from `plan-ready-guard`; retain `plan-commit-guard.mjs` as a standalone compatibility entry point.
- Rejected options: remove the commit guard entirely.
- Rationale: reduce process startup overhead without changing policy coverage.
- Consequences: one hook owns PreToolUse decision precedence; focused smoke coverage exercises both paths.

## Accepted Drift
- Original plan: potentially redesign task-loop continuation behavior.
- Implemented reality: `tasks-till-done` was not changed.
- Why accepted: Mac mini evidence showed repeated user/extension continuation prompts and configured caps, but no deterministic infinite auto-loop failure; changing it without a reproducer would be an evidence-free behavior regression.

## Validation Evidence
- `bash tests/claude-hooks-smoke.sh` — pass.
- `bash tests/dual-runtime-guard-matrix-smoke.sh` — pass.
- `bash tests/no-progress-mutate-deny-smoke.sh` — pass, including traversal, symlink, stale history, and runtime receipt fixtures.
- `bash tests/ledger-auto-emit-smoke.sh` — pass, including shell suffix and mutating lookalike rejection.
- `bash tests/workflow-event-smoke.sh` — pass, including activation non-overwrite.
- `bash tests/workflow-receipts-smoke.sh` — pass.
- `bash tests/ledger-selection-performance-smoke.sh` — pass; pointer path inspected 1 record and legacy fallback inspected 53 records.
- `cd pi && bun test ./extensions/__tests__/` — 226 pass, 0 fail.
- `scripts/verify-agentic-infra core` — exit 0.
- `scripts/verify-agentic-infra full` — exit 0.
- Fresh read-only diff review `ses_04142f286ffereNKl6N0SCrQe5` — `GO WITH NOTES`; only the documented single-writer/proxy TOCTOU limitation remains.

## Follow-up State
- Remaining risks: no OS-level lock or cryptographic pointer attestation; custom validation commands may be unmeasured; Mac mini deployment was intentionally not performed.
- Parking lot: reproduce and separately evaluate `tasks-till-done` continuation semantics; fix the Mac mini obvault wrapper PATH/runtime if synchronous retrieval is desired.
- Superseded docs/specs: none.
- Next links: `scripts/lib/ledger-integrity.mjs`, `scripts/lib/ledger-auto-emit.mjs`, `tests/ledger-selection-performance-smoke.sh`, `workflow/events.md`.
