# Codex App Subagents

## Purpose

Codex App uses the same Etabli orchestration semantics as Pi and Claude, but
with Codex-native mechanics. When the active runtime exposes `multi_agent_v1`,
Codex may delegate bounded sidecar packets to internal subagents. When it does
not, Codex keeps the same `.workflow/<slug>/` ledger and simulates packets with
isolated notes.

## Confirmed Runtime Evidence

For this repo, a Codex App subagent setup is `confirmed` only when all are true:

- the active tool surface exposes `multi_agent_v1.spawn_agent`;
- the active tool surface exposes `multi_agent_v1.wait_agent`;
- the active tool surface exposes `multi_agent_v1.close_agent`;
- a bounded subagent packet runs and returns a verifiable result;
- the orchestrator records the agent id or nickname, result status, integration
  decision, sandbox/approval posture, and close status in `.workflow/<slug>/`.

This proves the current Codex App runtime only. It does not prove Pi
`TaskExecute`, Claude Task* support, or future Codex surfaces.

## Usage Rules

- Use `codex-dynamic-workflows` for `/goal`, dynamic workflow, delegation,
  subagent, parallel-agent, or swarm-style requests.
- Create or update `.workflow/<slug>/` before spawning.
- Keep the immediate critical path local.
- Delegate only bounded, independent sidecar packets with clear ownership.
- Account for inherited sandbox/approval policy and extra token/tool cost before
  spawning.
- Close agents after their result is integrated.
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
