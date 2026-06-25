# P1 Local Evidence Review

## Observed Matches
- `tests/claude-hooks-smoke.sh` exists and matches the plan's local-smoke pattern: Bash, `set -euo pipefail`, `mktemp -d`, `fixture_input()`, `assert_contains`, and `assert_not_contains`.
- `tests/fixtures/claude-hooks/` exists and currently contains only router/guard fixtures, so adding `adr-*.json` fixtures is a scoped extension.
- `.github/workflows/agentic-infra.yml` does not run `tests/claude-hooks-smoke.sh`; the plan's “local, not CI” decision matches repo state.
- `claude/hooks/detect-adr-signal.mjs` already matches `package.json`, uses `last_assistant_message` first, falls back to transcript, and returns `systemMessage`.
- `claude/settings.workflow-hooks.json` already has the planned `Stop` hook with `timeout: 5`.
- `claude/skills/adr/SKILL.md` has `disable-model-invocation: true` and currently waits for explicit approval; adding a pre-approval clause is correctly in scope if the e2e needs write coverage.
- `PLAN.md` is `READY` and targets tests, not broad plugin refactoring.

## Observed Mismatches
- `PLAN.md:71` says the e2e asserts via `is_error`, and `PLAN.md:49` identifies JSON output as the source of that field, but the e2e commands at `PLAN.md:80` and `PLAN.md:83` omit `--output-format json`.
- `PLAN.md:101` allows reusing an existing `~/.claude/skills/adr`; without verifying the resolved target, the e2e can validate a stale/global skill instead of this repo's candidate.
- I could not independently re-run `claude --version` or `claude -p`; `claude` is blocked by the local lean-ctx shell allowlist. The plan's recorded `claude -p` evidence remains prior evidence, not freshly reproduced here.

## Local Implication
- The hook-smoke portion is well grounded and should be deterministic.
- The e2e portion needs stricter `claude -p` flags and skill-target checks before its result can be trusted.
