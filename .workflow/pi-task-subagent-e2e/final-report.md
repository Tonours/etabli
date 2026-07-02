# Final Report: Pi Task subagent e2e

## Outcome

Completed. The remaining gap is closed for this local Pi runtime: `TaskExecute` can spawn a real subagent through the `@tintinweb/pi-subagents` RPC bridge, and the subagent can complete the Etabli archive/delete contract.

## Accepted Results

- Added `npm:@tintinweb/pi-subagents` beside `npm:@tintinweb/pi-tasks` in tracked Pi settings.
- Added installer sync coverage so managed live Pi settings receive the scoped subagent provider.
- Installed `@tintinweb/pi-subagents@0.13.0` into the live Pi agent npm surface.
- Removed the ambiguous live `npm:pi-subagents` source from `~/.pi/agent/settings.json`.
- Extended `tests/workflow-real-agent-scenarios.sh` with `taskexecute-subagent-workflow`.
- The real scenario restricts the parent Pi process to Task* tools and verifies filesystem evidence after the subagent run.

## Rejected Results

- Rejected treating unscoped `npm:pi-subagents` as enough for TaskExecute; it does not provide the `subagents:rpc:*` protocol required by `@tintinweb/pi-tasks`.
- Rejected loading the scoped provider twice. When it is package-managed in live Pi settings, the test lets Pi load it normally; explicit `--extension` is only a fallback.

## Conflicts Resolved

- `@tintinweb/pi-tasks` plus `npm:pi-subagents` was a misleading partial setup. The repo now uses the exact scoped provider that implements protocol v2.
- A first test attempt failed because live package loading plus explicit `--extension` registered the same tools twice. The harness now avoids that duplicate path.

## Verification Evidence

- `bash -n tests/workflow-real-agent-scenarios.sh` passed.
- `bash -n scripts/install.sh` passed.
- `bash -n tests/workflow-docs-smoke.sh` passed.
- `bash tests/workflow-docs-smoke.sh` passed.
- `bun test pi/extensions/__tests__/settings-consistency.test.ts` passed with 4 tests.
- `PI_SKIP_VERSION_CHECK=1 /Users/tonours/.asdf/shims/pi install npm:@tintinweb/pi-subagents` installed `@tintinweb/pi-subagents@0.13.0`.
- `PI_SKIP_VERSION_CHECK=1 /Users/tonours/.asdf/shims/pi remove npm:pi-subagents` removed the unscoped package source from live Pi settings.
- `PI_SKIP_VERSION_CHECK=1 /Users/tonours/.asdf/shims/pi list` shows only `npm:@tintinweb/pi-tasks` and `npm:@tintinweb/pi-subagents` for this Task* pair.
- `RUN_REAL_AGENT_SCENARIOS=1 RUN_REAL_AGENT_PI=1 RUN_REAL_AGENT_CLAUDE=0 RUN_REAL_AGENT_TASKEXECUTE=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` passed.
- `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` passed with Pi `0.80.2` and Claude Code `2.1.196`.
- `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` passed with Pi `0.80.2` and Claude Code `2.1.196`.
- `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` passed again after removing `npm:pi-subagents`.
- The final scenario reported `PASS: taskexecute-subagent-workflow scenario`.

## Remaining Risks

- This is a confirmed local runtime guarantee, not a universal guarantee for future Pi versions or machines without the scoped provider installed.
- Real agent scenarios depend on live model availability and may be slower or fail under rate limits.

## Reusable Follow-up

- Keep `RUN_REAL_AGENT_SCENARIOS=1 tests/workflow-real-agent-scenarios.sh` as the regression gate before changing Task* or subagent packages.
