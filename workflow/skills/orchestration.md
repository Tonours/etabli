# Orchestration Contract

Shared contract for long-running Etabli orchestration across Pi and Claude.

Runtime adapters may differ in mechanics. They must preserve the same workflow
semantics, evidence requirements, stop conditions, and honesty labels.

## Runtime Adapters

Current capability labels and proof commands: `workflow/runtime-capabilities.json`.

- Pi may use Task* tools when available.
- Task* tools are Pi-only unless another runtime explicitly exposes equivalent
  structured task primitives.
- Claude should use Claude Code `/goal` for long-running completion loops.
- Hooks and commands route, guard, and add context; they must not invent runtime
  primitives that the host does not expose.
- Work is parent-only. The deterministic multi-model council was removed
  (ADR-0013) after the 2026-07-19 blind latency gate found no quality gain;
  subagent delegation remains an ordinary tool call, judged case by case.

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

- the user asked for delegation/subagents, or the active runtime profile marks
  the route and phase eligible because separate evaluators materially improve
  evidence;
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
- durable event trail per `workflow/events.md` when the run uses a
  `.workflow/<slug>/` directory;
- remaining risks.

Autonomous implementation loops are complete only when the implementation-loop
contract's completion evidence is present.

## Runtime Notes

Current capability labels and proof commands: `workflow/runtime-capabilities.json`.

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
  with an explicit cap (iterations or wall-clock) and record the event ledger
  per `workflow/events.md`, as required by `workflow/spec.md`.
- `plan-ready-guard.mjs` is an opt-in local hook that proves guard behavior in
  smoke tests. Route classification stays library-only
  (`claude/hooks/workflow-router-lib.mjs`), covered by `scripts/router-eval`.
- Hooks are deterministic guardrails for blocking. They do not inject route
  context, and they do not replace task state or completion evidence.
- Claude has no Pi Task* equivalent unless the active Claude runtime exposes one
  separately.
