# Orchestration Contract

Shared contract for long-running Etabli orchestration across Pi and Claude.

Runtime adapters may differ in mechanics. They must preserve the same workflow
semantics, evidence requirements, stop conditions, and honesty labels.

## Runtime Adapters

- Pi may use Task* tools and `tasks-till-done` when available.
- Task* tools are Pi-only unless another runtime explicitly exposes equivalent
  structured task primitives.
- Claude should use Claude Code `/goal` for long-running completion loops.
- Hooks and commands route, guard, and add context; they must not invent runtime
  primitives that the host does not expose.
- Subagents are optional sidecar evaluators or workers, not the default workflow.

## Capability Labels

Every runtime-dependent orchestration claim should use one label:

- `confirmed`: proven by local structured state, tests, hook output, command
  output, or a live runtime check from the current run.
- `proxy_supported`: supported by local source, package/config evidence, or smoke
  tests, but not proven by a live runtime execution in the current run.
- `blocked`: could not be checked because a required binary, permission,
  provider, tool, credential, or runtime surface is unavailable.
- `unknown`: evidence is absent, contradictory, or outside the current scope.

Do not convert `proxy_supported`, `blocked`, or `unknown` into completion.

## Task State

Prefer structured task state over text:

1. Use structured task details or a validated task store when the runtime exposes
   them.
2. Use text parsing only as a fallback and mark it `proxy_supported`.
3. If neither structured nor text evidence is parseable after a task tool call,
   attempt one recovery continuation, then stop as `blocked` or `unknown` with
   the evidence.

## Delegation

Delegate only when all are true:

- the user asked for delegation, subagents, a dynamic workflow, or the task is
  broad enough that a separate evaluator materially improves evidence;
- the subtask is bounded and independent;
- ownership is clear;
- the runtime exposes a supported runner;
- retry and stop conditions are already defined.

Keep the critical path local. Use fresh-context reviewer/oracle-style agents
before writer agents. Do not use subagents to hide uncertainty.

## Retry And Error Rules

- Retry only classified retryable failures: transient provider/runtime errors,
  missing context that can be supplied, timeout with partial useful output, or a
  validation failure with a clear next fix.
- Do not retry destructive, security-sensitive, production, billing, or external
  write actions without explicit approval.
- Cap retries per packet. After the cap, stop as `blocked` with attempts,
  evidence, and the next required input.
- Record failure class, attempted recovery, and final status.

## Acceptance Evidence

Each step or packet must leave enough evidence for the orchestrator to integrate
without trusting prose alone:

- objective and ownership;
- files or sources inspected;
- files changed, when edits were allowed;
- validation command or source checked;
- result label: accepted, rejected, blocked, or unknown;
- remaining risks.

Autonomous implementation loops are complete only when the implementation-loop
contract's completion evidence is present.

## Runtime Notes

Pi:

- `tasks-till-done` may continue Task* work until done, blocked, stalled, or at
  its limit.
- `TaskExecute` requires explicit subagent tracking capability; package presence
  alone is not enough.
- Treat `TaskExecute` as blocked until the `subagents:rpc:ping`,
  `subagents:rpc:spawn`, and `subagents:rpc:stop` protocol is confirmed in the
  active Pi runtime. A standalone `subagent` tool can still be useful, but it
  does not prove that `pi-tasks` can track status, cascade dependencies, or serve
  `TaskOutput`.

Claude:

- `/goal` is the native till-done mechanism.
- `workflow-router.mjs` and `plan-ready-guard.mjs` are opt-in local hooks that
  prove route/guard behavior in smoke tests.
- Claude has no Pi Task* equivalent unless the active Claude runtime exposes one
  separately.
