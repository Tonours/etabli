# Codex App Subagents

Canonical Codex configuration:
`codex/workflow/team-orchestration.md`.

## Purpose

Codex App uses the same Etabli orchestration semantics as Pi and Claude, but
keeps its runtime configuration separate under `codex/workflow/`. Its team
profile is ambient: every request is
automatically classified as `parent-only`, `scout`, `council`, or
`fresh-review`, without requiring the user to name a skill or delegation
keyword. When the active runtime exposes `collaboration`, Codex delegates
bounded sidecar packets under that classification. When it does not, Codex
keeps the same `.workflow/<slug>/` ledger and simulates required packets with
isolated notes.

## Confirmed Runtime Evidence

For this repo, a Codex App subagent setup is `confirmed` only when all are true:

- the active tool surface exposes `collaboration.spawn_agent`;
- the active tool surface exposes `collaboration.wait_agent`;
- the active tool surface exposes status inspection such as
  `collaboration.list_agents`;
- a bounded subagent packet runs and returns a verifiable result;
- the orchestrator records the agent id or nickname, result status, integration
  decision, inherited sandbox/approval posture, and final status in
  `.workflow/<slug>/`.

This proves the current Codex App runtime only. It does not prove Pi
`TaskExecute`, Claude Task* support, or future Codex surfaces.

## Usage Rules

- Apply `codex-dynamic-workflows` ambiently to ordinary requests as well as
  `/goal`, dynamic workflow, delegation, subagent, parallel-agent, or
  swarm-style requests.
- Automatically launch a read-only scout for non-trivial eligible work when a
  useful independent packet exists and the runner is available.
- Keep trivial, ineligible, tightly coupled, sensitive, and explicit opt-out
  work parent-only.
- Create or update `.workflow/<slug>/` before spawning.
- Keep the immediate critical path local.
- Delegate only bounded, independent sidecar packets with clear ownership.
- Account for inherited sandbox/approval policy and extra token/tool cost before
  spawning.
- Collect final status after integration; do not invent a close operation when
  the current surface omits one.
- Apply model effort, context inheritance, council capability, leaf-agent,
  messaging, and write ownership rules from
  `codex/workflow/team-orchestration.md`.
- Do not create user-owned Codex threads for subagent packets.
- Do not describe Codex subagents as Pi Task* tools.

## Fallback

If the runner is unavailable, mark the runtime claim `blocked`, write packet
prompts and simulated results under `.workflow/<slug>/`, and report the exact
missing surface. These simulated `.workflow/<slug>/` packets preserve the
workflow shape without silently claiming real delegation.

## Validation

Use the checks that match the change:

```bash
bash tests/codex-organization-smoke.sh
bash tests/workflow-docs-smoke.sh
python3 /Users/tonours/.codex/skills/codex-dynamic-workflows/scripts/verify_workflow.py .workflow/<slug>
git diff --check
```
