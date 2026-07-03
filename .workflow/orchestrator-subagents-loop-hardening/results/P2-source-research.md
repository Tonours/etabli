# Result P2: source research

Status: accepted

Access date: 2026-07-03

## Source-backed Claims

| Claim | Source | Label | Etabli implication |
| --- | --- | --- | --- |
| Codex subagents are explicit, token-expensive, and orchestrated by spawning, routing, waiting, and closing agent threads. Subagents inherit sandbox policy. | OpenAI Codex subagents docs: https://developers.openai.com/codex/subagents | confirmed | Keep Codex delegation explicit, record close status, and record sandbox/approval context for any real Codex subagent packet. |
| Codex Goals are bounded completion contracts with outcome, evidence, constraints, and blocker stop conditions. | OpenAI Cookbook: https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex | confirmed | Keep `/goal` prompts compact and evidence-driven; completion audit must prove the original success criteria. |
| Claude subagents are side contexts for specialized tasks, useful for preserving main context and constraining tools. | Claude Code subagents docs: https://code.claude.com/docs/en/sub-agents | confirmed | Claude parity can use native subagents when available, but Etabli must preserve tool/permission boundaries and avoid pretending Task* state exists. |
| Claude hooks provide deterministic control at lifecycle points and can block, inject context, or audit actions. | Claude Code hooks guide/reference: https://code.claude.com/docs/en/hooks-guide and https://code.claude.com/docs/en/hooks | confirmed | Keep Claude hooks as guardrails around workflow routing and READY gates, not as a hidden replacement for runtime task state. |
| Pi `TaskExecute` needs `@tintinweb/pi-subagents`; package presence must be paired with the RPC bridge that `pi-tasks` can track. | `@tintinweb/pi-tasks` docs and installed local README | confirmed | Keep `TaskExecute` blocked unless `subagents:rpc:*` tracking is proven in the active runtime. |
| Pi subagents run isolated sessions with their own tools, prompt, model, and thinking level, and support parallel/background steering. | `@tintinweb/pi-subagents` docs and installed local README | confirmed | Record packet ownership, runtime, and retrieval path; avoid duplicate loading and avoid using standalone subagent tools as proof of Task* tracking. |
| ReAct supports interleaving reasoning/actions and using observations to update plans and handle exceptions. | ReAct paper: https://arxiv.org/abs/2210.03629 | confirmed | Require retries to be evidence-consuming: observation -> hypothesis -> next action, not blind reruns. |
| Reflexion improves agents by converting feedback into explicit linguistic memory for subsequent attempts. | Reflexion paper: https://arxiv.org/abs/2303.11366 | confirmed | Store failed packet attempts, feedback, and accepted recovery in workflow results before retrying. |
| AutoGen shows multi-agent systems need programmable conversation patterns and explicit interaction behavior. | AutoGen paper: https://arxiv.org/abs/2308.08155 | confirmed | Keep packet ownership, routing, and integration policy explicit rather than letting agents freely coordinate. |
| Voyager's iterative prompting uses environment feedback, execution errors, and self-verification to improve programs. | Voyager paper: https://arxiv.org/abs/2305.16291 | confirmed | Require completion evidence from actual validation/runtime artifacts, not prose-only completion claims. |

## Accepted Hardening Directions

- Add explicit sandbox/permission/cost context to subagent packet evidence.
- Add an evidence-consuming retry rule: each retry needs observation,
  hypothesis, and next validation.
- Add a source-backed claim matrix doc for future maintainers.
- Strengthen smoke tests to keep these rules in the shared workflow contract.

## Rejected Directions

- No new external orchestrator. Current repo should keep Pi/Claude/Codex as thin
  adapters over the shared workflow contract.
- No universal guarantee for Codex, Claude, or Pi subagent stability.
- No broad "agentic best practices" prose without testable impact.
