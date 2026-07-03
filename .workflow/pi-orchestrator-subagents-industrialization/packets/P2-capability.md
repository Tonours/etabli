# P2 capability

## Owner

Subagent audit, integrated by main agent.

## Status

Completed.

## Scope

Check local Pi, Claude, and subagent capability evidence without assuming that installed packages imply runtime stability.

## Integration Criteria

- Every runtime-dependent claim gets one of `confirmed`, `proxy_supported`, `blocked`, or `unknown`.
- `TaskExecute` subagent cascade is not used unless the expected RPC bridge is proven.
- Claude parity is not represented as Task* parity.
