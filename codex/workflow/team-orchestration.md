# Codex Team Orchestration Profile

This file is the runtime-specific source of truth for Codex team activation,
model effort, context inheritance, delegation, peer messaging, write ownership,
and council capability. Shared workflow semantics, evidence, retries, and
authorization remain in `workflow/skills/orchestration.md`.

## Ambient Activation

Apply this profile on every Codex request. The user does not need to invoke a
skill or mention agents. Classify execution as `parent-only`, `scout`,
`council`, or `fresh-review`.

- Use `parent-only` for simple answers, trivial edits, ineligible or sensitive
  routes, tightly coupled work, explicit opt-out, or when no independent packet
  would materially improve evidence.
- Architecture, cross-module scope, or general non-triviality alone stays
  `parent-only`. Launch a read-only scout only for material uncertainty,
  repeated failure, explicit multi-agent intent, critical risk, or a required
  fresh-context review.
- After implementation, use a fresh-context read-only reviewer when the
  implementation-loop contract requires it.
- `single-agent`, `agent unique`, `no-panel`, or `sans panel` opts out.

## Codex Roles

- Coordinator: active Sol parent at the current effort; stays user-facing,
  writes, integrates, validates, and owns the final verdict.
- Scout: Terra `low`, `fork_turns: "none"`, narrow read-only evidence packet.
- Supporting analyst: Terra `medium`, fresh or targeted context, read-only.
- Difficult analyst or reviewer: Terra `high`, preferably fresh context,
  read-only.
- Adjudicator: Sol once, only after deterministic checks leave a material
  disagreement.

Use direct `spawn_agent` model and reasoning overrides only when the active
collaboration surface exposes them. Luna is unavailable unless a live spawn
proves Luna provenance. GLM and Kimi are unavailable in Codex until a proven
Responses-compatible transport and user-owned authentication exist.

## Packet And Context Rules

- Give every packet one owned question, evidence format, model/effort, budget,
  stop rule, and all applicable safety and permission constraints.
- Start scouts and reviewers with `fork_turns: "none"` unless inherited
  conversation context is essential.
- Inherited-context agents still receive an explicit ownership boundary.
- Every sidecar is a leaf: it completes its packet directly and must not spawn
  agents or delegate further.
- Keep first-pass packets independent. Do not rebroadcast full transcripts or
  perform open-ended all-to-all discussion.
- Direct peer messages may deliver only a concrete dependency or evidence
  needed by another owned packet.

## Write And Integration Rules

- Sidecars are read-only in the shared worktree. Codex children inherit the
  parent's filesystem posture, so enforce this contractually and verify the
  diff before accepting a result.
- The parent is the only writer. It accepts or rejects findings, applies
  changes, runs deterministic checks, and owns the final decision.
- Deterministic checks outrank model judgments. There is no majority vote or
  forced consensus.
- Two sidecars is the automatic ceiling. More requires explicit user approval.

## Codex Council Admission

Council selection is deterministic and Codex-specific:

- critical signal: security, vulnerability, auth/authz, race, deadlock,
  concurrency, transaction/atomicity, data loss, or destructive migration;
- medium system signal: architecture, distributed or cross-module work,
  refactor, performance/scalability, or API contract;
- medium uncertainty signal: root cause, intermittent/flaky behavior, unclear
  trade-off, or conflicting evidence;
- medium failure-history signal: two failed attempts or a repeated regression.

One system-complexity signal stays parent-only. One uncertainty or
failure-history signal admits a Terra scout. One critical signal or two
distinct medium signals requests a council. Explicit multi-agent intent may
request a council but cannot make an unsupported participant portfolio valid.
Sensitive or externally mutating routes remain parent-only.

A Codex council requires a live protocol-compatible second participant distinct
from Terra and the Sol adjudicator. Without one, retain the Terra scout plus
parent integration with `degraded` status, or stop as `blocked` when two
independent participants are mandatory. Never claim a council ran.

## Runtime Evidence And Fallback

A Codex runner is `confirmed` for the current session only when
`spawn_agent`, `wait_agent`, status inspection, and one bounded packet return
verifiable evidence. Record agent id, model override, packet ownership,
inherited sandbox/approval posture, result, integration decision, and final
status when the run has a ledger.

Codex subagents are internal sidecars, not Pi Task* workers and not user-owned
Codex threads. Do not invent a `close_agent` operation when the active surface
does not expose one.

If the runner is absent, mark delegation `blocked` or `unknown`. For a durable
workflow that requires packet artifacts, simulate isolated read-only packet
passes under `.workflow/<slug>/`, but never describe them as real subagent
execution.
