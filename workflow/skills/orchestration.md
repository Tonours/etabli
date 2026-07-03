# Orchestration Contract

Shared contract for long-running Etabli orchestration across Pi, Claude, and
Codex.

Runtime adapters may differ in mechanics. They must preserve the same workflow
semantics, evidence requirements, stop conditions, and honesty labels.

## Runtime Adapters

- Pi may use Task* tools and `tasks-till-done` when available.
- Task* tools are Pi-only unless another runtime explicitly exposes equivalent
  structured task primitives.
- Claude should use Claude Code `/goal` for long-running completion loops.
- Codex App may use its multi-agent runner when the active runtime exposes one;
  otherwise it should simulate packets through `.workflow/<slug>/`.
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
- sandbox, approval, tool, and cost/token implications are understood for that
  runtime;
- retry and stop conditions are already defined.

Keep the critical path local. Use fresh-context reviewer/oracle-style agents
before writer agents. Do not use subagents to hide uncertainty.

## Retry And Error Rules

- Retry only classified retryable failures: transient provider/runtime errors,
  missing context that can be supplied, timeout with partial useful output, or a
  validation failure with a clear next fix.
- Each retry must consume new evidence: record the observation, failure
  hypothesis, next action, and validation that will prove or reject the recovery.
  Do not blindly rerun the same packet.
- Do not retry destructive, security-sensitive, production, billing, or external
  write actions without explicit approval.
- Cap retries per packet. After the cap, stop as `blocked` with attempts,
  evidence, and the next required input.
- Record failure class, attempted recovery, and final status.

## Acceptance Evidence

Each step or packet must leave enough evidence for the orchestrator to integrate
without trusting prose alone:

- objective and ownership;
- runtime adapter plus sandbox, approval, and tool/permission context;
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
- Hooks are deterministic guardrails for routing, blocking, and context
  injection. They do not replace task state or completion evidence.
- Claude has no Pi Task* equivalent unless the active Claude runtime exposes one
  separately.

Codex:

- `codex-dynamic-workflows` is the orchestration front door for `/goal`,
  subagents, delegation, and dynamic workflow requests.
- In Codex App, a visible `multi_agent_v1` runner with `spawn_agent`,
  `wait_agent`, and `close_agent` is `confirmed` evidence for this runtime only.
- Codex subagents are internal sidecar workers or reviewers. They are not Pi
  Task* tools, and they are not user-owned Codex threads.
- Codex subagents inherit the current sandbox/approval posture and can consume
  extra model/tool budget. Record that posture when accepting a real subagent
  result.
- If the runner is absent, use simulated packets under `.workflow/<slug>/` and
  label the runtime claim `blocked` rather than pretending delegation happened.
