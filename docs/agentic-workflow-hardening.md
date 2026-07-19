# Agentic Workflow Hardening Notes

Source-backed notes for the Etabli orchestration contract. This is not a new
workflow; it explains why the current Pi, Claude, and Codex adapters are kept
thin and what evidence each loop must leave behind.

Access date: 2026-07-03.

## Source Matrix

| Source | Relevant claim | Etabli rule |
| --- | --- | --- |
| OpenAI Codex subagents docs, https://developers.openai.com/codex/subagents | Codex subagents are explicit, orchestrated, may consume extra model/tool work, and inherit sandbox policy. | Spawn only on explicit/authorized delegation; record runner evidence, sandbox/approval posture, result, and the final status the active surface exposes. |
| OpenAI Codex Goals cookbook, https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex | Goals are scoped completion contracts with outcome, evidence, constraints, and blocker conditions. | `/goal` prompts must state a verifiable end state and cannot be marked complete from weak or indirect evidence. |
| Claude Code subagents docs, https://code.claude.com/docs/en/sub-agents | Subagents preserve main context, can specialize behavior, and run with configured tools/permissions. | Use Claude subagents only as side contexts; do not claim Pi Task* state unless a runtime exposes it. |
| Claude Code hooks docs, https://code.claude.com/docs/en/hooks-guide and https://code.claude.com/docs/en/hooks | Hooks provide deterministic lifecycle control for blocking, injecting context, and auditing. | Hooks may route and guard Claude workflows, but final completion still requires task or validation evidence. |
| `@tintinweb/pi-tasks` and `@tintinweb/pi-subagents` local/GitHub docs | `TaskExecute` subagent execution requires the scoped subagent provider and RPC tracking bridge. | Treat Pi `TaskExecute` as `blocked` until `subagents:rpc:*` tracking is confirmed in the active runtime. |
| ReAct paper, https://arxiv.org/abs/2210.03629 | Agents improve by interleaving actions with observations that update plans and handle exceptions. | Retries must consume an observation and produce a changed next action, not rerun blindly. |
| Reflexion paper, https://arxiv.org/abs/2303.11366 | Agents can use feedback traces as memory for later attempts. | Failed packet attempts must record feedback, hypothesis, and accepted recovery before retrying. |
| AutoGen paper, https://arxiv.org/abs/2308.08155 | Multi-agent applications need explicit conversation and interaction patterns. | Keep packet ownership, integration policy, and conflict resolution explicit in `.workflow/<slug>/`. |
| Voyager paper, https://arxiv.org/abs/2305.16291 | Iterative improvement uses environment feedback, execution errors, and self-verification. | Completion evidence must include validation/runtime artifacts, not prose-only success claims. |

## Hardening Rules

- **Delegate deliberately.** A subagent packet needs clear ownership, bounded
  scope, runner availability, and a recorded sandbox/approval/tool context.
- **Retry with evidence.** Each retry records observation, failure hypothesis,
  next action, and the validation signal that will close the loop.
- **Keep completion auditable.** A workflow is complete only when tests, runtime
  state, or generated artifacts prove the original acceptance criteria.
- **Preserve adapter honesty.** Pi Task* state, Claude hooks/subagents, and
  Codex `collaboration` agents are different runtime surfaces; use capability labels
  instead of flattening them into one generic "subagent" claim.
