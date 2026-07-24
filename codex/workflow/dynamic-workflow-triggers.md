# Dynamic Workflow Trigger Recipe

Canonical Codex configuration: `workflow/team-orchestration.md`.

## Trigger
- ambient on every Codex request; no explicit workflow keyword is required
- `/goal`
- explicit agent `workflow` or `dynamic workflow`
- explicit `subagents`, `parallel agents`, `delegate`, or `swarm`
- broad risky work where orchestration reduces drift

## Plan Shape
1. Restate the goal and success criteria.
2. Identify repository/workspace, current state, validation, and out-of-scope actions.
3. Create/update `.workflow/<slug>/` when the work is substantial or may span turns.
4. Classify the request as `parent-only`, `scout`, `council`, or
   `fresh-review`.
5. Split into packets only when there are independent tracks.
6. Keep the immediate critical path local.
7. Automatically delegate a read-only scout for non-trivial eligible work with
   a useful independent packet.
8. Integrate results, resolve conflicts, and verify.

Codex App note: `collaboration.spawn_agent`, `wait_agent`, and status inspection
are confirmed runner evidence only for the active runtime that exposes them.
When they are absent, keep the same plan shape and simulate packets under
`.workflow/<slug>/`.

## Packet List
- Discovery or source-of-truth audit
- Implementation slice with disjoint ownership
- Tests or validation
- Docs or handoff
- Security/risk review for sensitive work

## Verification Checklist
- Workflow artifact has goal, criteria, context, risks, packets, integration policy, and verification.
- Ambient mode was evaluated without requiring an explicit user keyword.
- Subagents were spawned only when the adaptive profile or user authorization applied and the packet was useful.
- Non-trivial eligible work with a useful independent packet received an
  automatic scout when the runner was available.
- A council was selected only by the canonical deterministic profile and only
  with a proven protocol-compatible participant portfolio.
- Codex App subagent runs record agent id/nickname, model override, packet
  ownership, accepted/rejected result, inherited posture, and final status.
- Retry attempts record observation, failure hypothesis, next action, and the
  validation that will prove or reject recovery.
- Packet ownership was disjoint.
- Sidecars were read-only leaf agents; the parent remained the only writer.
- Final answer distinguishes observed facts from assumptions where relevant.
- Checks match the blast radius.

## Known Risks
- Over-orchestration slows trivial tasks.
- Vague keyword matching can trigger unintended workflows.
- Subagents can duplicate work without strict packet ownership.
- Incidental mentions of CI/GitHub workflows should not trigger agent orchestration.
- Some Codex surfaces may not expose a subagent runner; simulate packets in that case.
- A visible Codex App runner proves only the current runtime, not Pi, Claude, or
  every future Codex surface.
