# Implemented: live proof fixes + P2 docs-smoke hygiene

## Metadata
- Archived: 2026-07-29
- Status: IMPLEMENTED

## Outcome

### Live proof
- Pi: CLI smoke + 7 real-agent scenarios (incl. TaskExecute) green.
- Claude: after `~/.local/bin` on PATH, CLI + 6 real-agent scenarios green.
- Fixes: realpath re-export for ledger-auto-emit under Pi symlinks; scaffold
  `maps, not manuals`; normalize_agent_output no longer scrapes path fragments
  from SessionEnd hook noise.

### P2 G6 hygiene
- Thinned `tests/workflow-docs-smoke.sh`: ~816 → ~572 lines; `assert_contains`
  ~475 → ~227.
- Dropped event-list / phrase re-pins covered by behavioral smokes; kept
  structure, max-lines, adapter→contract matrix, anti-Codex not-contains,
  critical honesty pins.

## Validation
- Live logs: `/tmp/real-agent3.log`, `/tmp/claude-real-agent3.log`, CLI smokes
- `bash tests/workflow-docs-smoke.sh` → ok
- `scripts/verify-agentic-infra core` (after commit)

## Non-goals still deferred
- Host product Stop-hook thrash cap / Codex anti-spin / write retry budget
- Live pass@k budgets
- Capability `confirmed` for multi-model without dedicated `RUN_REAL_MULTI_MODEL`
