# Night Shift (Native Pi Extension)

`/nightshift` is a native Pi extension for overnight batch tasks:
- prepare 1–3 tasks before leaving
- execute each task in its own worktree
- run verify commands
- commit + push automatically (unless `--verify-only`)

No external dependencies required (no python3, jq).

## Commands

```
/nightshift init [--force]          — Create tasks template
/nightshift list                    — List parsed tasks with status
/nightshift run [options]           — Execute tasks
/nightshift status                  — Show task state
/nightshift clean                   — Purge stale worktrees
/nightshift-quick --repo <n> ...    — Quick task add
```

### Run options

- `--dry-run` — Parse and validate only, no execution
- `--verify-only` — Run engine + verify but skip commit/push
- `--require-verify` — Fail tasks without verify commands
- `--only id1,id2` — Run specific tasks only
- `--limit N` — Limit number of tasks to run

## Routine

Prep (around 17:00–17:30):
- `/nightshift init`
- edit `~/.local/state/nightshift/tasks.md`
- `/nightshift run --dry-run` to validate parsing

Before leaving:
- `/nightshift run`

If you only want execution + checks (no commit/push):
- `/nightshift run --verify-only`

If you want strict task hygiene (every task must define verify commands):
- `/nightshift run --require-verify`

Next morning:
- `/nightshift status`
- check `~/.local/state/nightshift/last-run-report.md`

## Task Format

Each task is a block:

```md
## TASK fix-login-redirect
repo: my-repo
base: main
branch: night/fix-login-redirect
engine: codex
verify:
- bun test
- bun run lint
prompt:
Fix the login redirect loop.

Context:
- Users on /app are redirected back to /login even after auth.

DoD:
- tests pass
- no new lints
- minimal diff
ENDPROMPT
```

Fields:
- `repo:` repository name under `$PI_PROJECT_ROOT` (default `~/projects`)
- `path:` absolute path to a repository (overrides `repo:`)
- `base:` base branch (default `main`)
- `branch:` target branch (default `night/<id>`)
- `engine:` `codex` (default) | `none`
- `verify:` commands to run after implementation
- `prompt:` multi-line block ending with `ENDPROMPT`

## Run Output Files

- `~/.local/state/nightshift/last-run-report.md` (latest run summary)
- `~/.local/state/nightshift/last-run-report.json` (machine-readable summary)
- `~/.local/state/nightshift/history.jsonl` (per-task history for metrics)
- `~/.local/state/nightshift/logs/<task>-<timestamp>.log` (engine logs)

## Reliability Guarantees

- commit/push errors are treated as failures (no silent success)
- failed tasks are marked with explicit `lastError`
- each task is appended to history with status and verify result
- selective git add (no `git add -A`) to avoid committing unrelated files
- atomic write-rename for state and history files

## Engines

### `engine: codex`
Runs `codex exec --full-auto` in the worktree.

### `engine: none`
Skips LLM execution; useful for pre-creating worktree + branch.

## Guardrails

- no PR creation
- no merge
- no browser

## Architecture

The extension is composed of focused modules in `pi/extensions/lib/nightshift/`:
- `config.ts` — Environment variable resolution
- `parse-tasks.ts` — Markdown task parser (state machine)
- `state.ts` — Atomic state.json read/write
- `history.ts` — JSONL history append/read/prune
- `worktree.ts` — Git worktree creation/cleanup
- `engine.ts` — Engine execution (codex spawn)
- `verify.ts` — Verify command runner
- `git-ops.ts` — Selective git add, commit, push
- `report.ts` — Markdown and JSON report generation
- `checks.ts` — Binary availability checks

## Troubleshooting

- ensure the machine does not sleep overnight
- validate task parsing first: `/nightshift list` + `/nightshift run --dry-run`
- inspect logs and `last-run-report.md` for failures
- `/nightshift clean` to purge stale worktrees
