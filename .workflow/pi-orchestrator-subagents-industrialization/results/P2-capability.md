# P2 capability audit

## Verdict

`CONFIRMED_LOCAL_RUNTIME` for Pi `TaskExecute` subagent execution on this machine after installing the scoped provider.

This remains a local runtime guarantee, not a universal guarantee for every Pi version or machine.

## Evidence

- `confirmed`: `workflow/spec.md` remains the canonical contract and keeps Pi as the primary workflow surface with thin adapters.
- `confirmed`: local `tasks-till-done` logic now distinguishes structured task evidence from text fallback and has focused tests.
- `confirmed`: `npm:@tintinweb/pi-tasks` is configured and installed, and `pi list` works through `/Users/tonours/.asdf/shims/pi`.
- `confirmed`: `@tintinweb/pi-subagents@0.13.0` is installed in the live Pi agent npm surface and paired with `@tintinweb/pi-tasks` in tracked settings.
- `confirmed`: `RUN_REAL_AGENT_SCENARIOS=1 REAL_AGENT_RETRIES=1 tests/workflow-real-agent-scenarios.sh` passed with real Pi `0.80.2`, real Claude Code `2.1.196`, and the `taskexecute-subagent-workflow` e2e.
- `confirmed repo / blocked live activation`: Claude hooks and command files are testable in the repo, but live `~/.claude/settings.json` activation was not proven.

## Accepted

- Keep explicit labels: `confirmed`, `proxy_supported`, `blocked`, `unknown`.
- Prefer structured task-state evidence when available.
- Treat TaskList text parsing as a fallback, not a hard guarantee.
- Treat Pi `TaskExecute` subagent cascade as confirmed only when the scoped RPC bridge is installed and the real scenario passes; otherwise keep the existing `runtime_capability_blocked` path.
- Treat Claude parity as command/hook/`/goal` parity, not Task* parity.

## Rejected

- No claim of "100% guaranteed" runtime orchestration from package presence alone.
- No assumption that the Codex subagent runner proves Pi-native subagent stability.
