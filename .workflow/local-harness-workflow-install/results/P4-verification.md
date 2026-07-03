# P4 Verification

## Commands Passed

- `bash tests/deploy-agent-workflow-smoke.sh`
- `bash tests/workflow-docs-smoke.sh`
- `bash tests/codex-organization-smoke.sh`
- `bash tests/claude-hooks-smoke.sh`
- `bun test pi/extensions/__tests__/`
- `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh`

## Runtime Evidence

- Pi CLI detected: `0.80.2`.
- Claude Code detected: `2.1.196`.
- Codex CLI detected: `codex-cli 0.142.5`.
- Real scenarios passed: `scaffold-map`, `ready-read-only`,
  `adversarial-code-review`, `read-only-adversarial-plan`, `ready-implement`,
  `prompt-only-ready`, `codex-subagents-contract`, and
  `taskexecute-subagent-workflow`.

## Post-Deploy State

- Codex tracked files: 372 repo symlinks, 0 missing, 0 same-copy, 0 divergent.
- Pi scoped subagent packages are present as tracked objects.
- `npm:pi-subagents` legacy package is absent from live Pi settings.
- `scripts/deploy-agent-workflow --dry-run` reports no remaining planned changes.
