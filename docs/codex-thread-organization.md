# Codex Thread Organization

The thread organization routine is tracked under `codex/thread-organization/`.
It is a deterministic local sidecar for keeping Codex threads navigable.

## Included

- `build_thread_organization.py`
- `run_hourly_thread_organization.sh`
- operating docs, routing docs, queue docs, starter prompts
- templates and source files that generate local review surfaces

## Excluded

- generated reports
- `thread-index.*`
- `hourly-dashboard.md`
- `last-*.json`
- SQLite backups
- Python bytecode
- thread IDs, raw titles, and live queues

## Active Reference Thread

The active hourly organization reference thread stays in the local generated
queues. Its exact thread ID and raw title are not tracked in this repository.

The tracked docs preserve this workflow, but the generated report outputs remain
local runtime state.
