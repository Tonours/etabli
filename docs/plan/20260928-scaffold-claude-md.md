# Implemented: scaffold stops shipping a project CLAUDE.md

## Metadata
- Archived: 2026-09-28
- Source plan: `PLAN.md` — stop the scaffold shipping a project CLAUDE.md and restore green core checks
- Source plan SHA-256: `12f9fd970fc636f83826e3c828adde857e8abf2c258155e764ab1b31db474139`
- Status: IMPLEMENTED
- Commit / branch: `a487220e` on `main`, pushed

## Outcome
- `deploy-workflow` no longer writes `CLAUDE.md`; template deleted; scaffold smoke asserts its absence. Etabli rules live in the user-level workflow adapter.
- Pi skill block back under the gate (7141/7190): `!autoproject`, `!alambic-obvault` denied; `adversary` and `sec-pr` descriptions shortened; adapter hashes and skills lock rotated.
- July ledgers `agent-first-hardening`, `e2e-loop` pinned as grandfathered amendments.
- Live-only: stale skill links re-deployed (`deploy-agent-workflow --apply`), Pi npm DMI stamps applied.

## Validation
- Scaffold and docs smokes: ok; `workflow-ledger-check`: failed=0; `pi-skill-load-check`: rc=0; `verify:skills`: 80 hashes.
- `verify-agentic-infra all` before push: 2 failures (skill-lock, guards-active live DMI stamp), both fixed after; full group not re-run.

## Follow-up
- Commit bundles three behaviors (scaffold, Pi budget, ledger pins) against one-behavior-per-commit.
