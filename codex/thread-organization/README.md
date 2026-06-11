# Codex Thread Organization

This is a safe organization layer for Codex threads. It refreshes sidecar reports and performs only three bounded SQLite maintenance actions: add missing context prefixes to `threads.title`, point each thread `cwd` at `$CODEX_THREADS_ROOT/<context>`, and archive stale `archive_candidate` threads.

## Files

- `101.md`: start-here guide for using the thread organization system.
- `operating-system.md`: the collaboration model and thread naming rules.
- `workflow-routing.md`: profile routing for `codex-dynamic-workflows`.
- `starter-prompts.md`: prompts for starting, resuming, and closing workflow-shaped threads.
- `queues.md`: local generated operational queues for now, waiting, next, reference, and archive candidates.
- `hourly-dashboard.md`: local generated compact hourly view of recent, changed, waiting, and high-token threads.
- `cleanup-candidates.md`: local generated inventory of empty workspaces, legacy dated folders, and archive candidates.
- `thread-index.md`: local generated human-readable index.
- `thread-index.json`: local generated machine-readable index.
- `thread-index.csv`: local generated spreadsheet-friendly index.
- `suggested-thread-titles.md`: local generated rename plan, not applied automatically.
- `last-run-summary.json`: local generated machine-readable summary of the last run.
- `build_thread_organization.py`: regeneration script.

## Regenerate

```bash
python3 ~/.codex/thread-organization/build_thread_organization.py
```

## Hourly Routine

A local launchd job can run the script hourly. This does not create hourly Codex model threads; it refreshes local sidecar files and applies the bounded maintenance actions above.

## Safety

Generated outputs may include thread IDs, titles, dates, workspace labels, lanes, profiles, and statuses. Keep them local.
