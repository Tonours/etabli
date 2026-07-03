# P2 real e2e result

## Status

Accepted.

## Evidence

- Live Pi package install: `@tintinweb/pi-subagents@0.13.0`.
- Live Pi settings cleanup: `npm:pi-subagents` removed; `pi list` shows `npm:@tintinweb/pi-tasks` plus `npm:@tintinweb/pi-subagents`.
- Pi CLI: `0.80.2`.
- Parent Pi command path: `tests/workflow-real-agent-scenarios.sh`.
- Parent Pi tools: `TaskCreate,TaskList,TaskExecute,TaskOutput,TaskGet` with `--no-builtin-tools`.
- `RUN_REAL_AGENT_SCENARIOS=1 RUN_REAL_AGENT_PI=1 RUN_REAL_AGENT_CLAUDE=0 RUN_REAL_AGENT_TASKEXECUTE=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` passed.
- Full `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` passed and emitted `PASS: taskexecute-subagent-workflow scenario`.
- Full documented `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` passed and emitted `PASS: taskexecute-subagent-workflow scenario`.
- Full documented `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` passed again after removing the ambiguous unscoped package.

## Result

Confirmed on this local runtime: Pi `TaskExecute` can spawn a real subagent through the scoped provider and the subagent can produce archive/delete completion evidence.
