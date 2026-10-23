# Orchestration Contract

Shared contract for long-running Etabli orchestration across Pi and Claude.

Runtime adapters may differ in mechanics. They must preserve the same workflow
semantics, evidence requirements, stop conditions, and honesty labels.

## Runtime Adapters

Capability claims cover Etabli's managed integrations, Pi and Claude, unless
they explicitly discuss native host tools. Record any observed execution
with its scope; a successful local dispatch does not establish support across
all hosts. Missing general evidence is `unknown`, not proof that the native
capability is unavailable. Source inspection can correct the scope of a claim
but cannot confirm runtime support.

- Pi may use Task* tools when available.
- Task* tools are Pi-only unless another runtime explicitly exposes equivalent
  structured task primitives.
- Hooks only guard writes (ADR-0036); hooks and commands must not invent
  runtime primitives that the host does not expose.
- Single writer: `workflow/skills/implementation-loop.md` step 8. The current
  Pi profile remains parent-only while its subagent capability is `unknown`.
- A `scout`, `reviewer`, or `adversary` report whose last line is not
  `STATUS: complete` counts as truncated: rerun or narrow it, never read it as
  clean.

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

- the user asked for delegation/subagents, or the active implementation route
  explicitly permits one bounded worker, or the runtime profile marks the phase
  eligible because a separate evaluator materially improves evidence;
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

- `TaskExecute` requires explicit subagent tracking capability; package presence
  alone is not enough.
- Treat full `TaskExecute` tracking as unconfirmed until `subagents:rpc:ping`,
  `subagents:rpc:spawn`, and `subagents:rpc:stop` are all confirmed in the
  active Pi runtime. A direct `Agent` tool can still be confirmed separately; it
  does not prove that `pi-tasks` can track status, cascade dependencies, or serve
  `TaskOutput`.

Claude:

- `/goal` is the native till-done mechanism. Pair the measurable condition
  with an explicit cap (iterations or wall-clock) and record evidence in
  `PLAN.md`, as required by `workflow/spec.md`.
- Hooks do not route or inject context, and they do not replace task state or
  completion evidence.
- Claude has no Pi Task* equivalent unless the active Claude runtime exposes one
  separately.
