# Night Shift (Local Runner)

`scripts/nightshift` is a local overnight runner designed to keep working while you sleep:
- prepare 1–3 tasks before leaving
- the machine executes them (LLM or not) in worktrees
- it does `commit + push` automatically (no PR, no merge)

## Installation

If you installed the setup via `scripts/install.sh`, `nightshift` should already be in your PATH.

## Routine

Prep (around 17:00–17:30):
- `nightshift init`
- edit `~/.local/state/nightshift/tasks.md`
- `nightshift run --dry-run` to validate parsing

Before leaving (19:30 or whenever):
- `nightshift run`

Next morning:
- `nightshift status`

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
- `path:` absolute path to the repository (overrides `repo:`)
- `base:` base branch (default `main`)
- `branch:` target branch (default `night/<id>`)
- `engine:` `codex` (default) | `none`
- `verify:` list of commands to run after implementation (optional but recommended)
- `prompt:` multi-line prompt block ending with `ENDPROMPT`

## Worktrees / Branches

For each task:
- a worktree is created/reused under `$PI_WORKTREE_ROOT` (default `~/projects/worktrees`)
- the branch is created if needed and pushed at the end

## Engines

### engine: codex

Runs `codex exec --full-auto` inside the worktree.

### engine: none

Does not run an LLM. Useful if you only want to pre-create worktree + branch.

## Guardrails / Limitations

- no PR
- no merge
- no browser
- low noise: logs are written to `~/.local/state/nightshift/logs/`

## Troubleshooting

- ensure the machine does not go to sleep (macOS: Energy/Battery settings)
- validate with `nightshift list` and `nightshift run --dry-run`
- read logs at `~/.local/state/nightshift/logs/<task>-<timestamp>.log`
