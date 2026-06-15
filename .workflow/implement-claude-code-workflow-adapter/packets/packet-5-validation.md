# Packet 5: Final Validation

## Objective
Run the required local checks, record failures or blockers, and complete the
workflow only when evidence is sufficient.

## Result
Accepted.

## Evidence
- `bash tests/claude-hooks-smoke.sh`
- `bash tests/workflow-docs-smoke.sh`
- `bash tests/fix-links-smoke.sh`
- `bash tests/install-smoke.sh`
- `bash tests/workflow-scaffold-smoke.sh`
- `RUN_AGENT_CLI_SMOKE_SELF_TEST=1 bash tests/workflow-cli-smoke.sh`
- `RUN_AGENT_CLI_SMOKE=1 bash tests/workflow-cli-smoke.sh`
- `RUN_AGENT_CLI_SMOKE=1 RUN_CLAUDE_PRINT_SMOKE=1 bash tests/workflow-cli-smoke.sh`
- `bun test pi/extensions/__tests__/`
- `bash scripts/check-fix-symlinks.sh --verbose`
- `claude --version`
- `git diff --check`
- terminology search for `harness` returned only source-title/legacy-cleanup
  occurrences outside the new Claude adapter.
