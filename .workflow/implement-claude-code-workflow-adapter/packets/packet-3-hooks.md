# Packet 3: Claude Workflow Hooks

## Objective
Add deterministic Claude hook scripts for route context and READY-plan guarding.

## Result
Accepted.

## Files
- `claude/hooks/workflow-router-lib.mjs`
- `claude/hooks/workflow-router.mjs`
- `claude/hooks/plan-ready-guard.mjs`
- `claude/settings.workflow-hooks.json`
- `tests/fixtures/claude-hooks/*.json`
- `tests/claude-hooks-smoke.sh`

## Evidence
- `bash tests/claude-hooks-smoke.sh`
- `bash scripts/check-fix-symlinks.sh --verbose`
