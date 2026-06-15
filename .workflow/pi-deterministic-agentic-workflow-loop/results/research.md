# Web Research Notes

Research date: 2026-06-14.

Sources were selected from primary or recognized documentation and papers.

## Confirmed Claims

- Anthropic's "Building effective agents" identifies composable workflows such
  as orchestrator-workers and evaluator-optimizer. It says orchestrator-workers
  fit complex tasks where subtasks cannot be predicted, and evaluator-optimizer
  uses generation plus evaluation in a loop.
  Source: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic's long-running application development article reports that
  planner/generator/evaluator separation, tractable chunks, and structured
  handoff artifacts improved long-running autonomous coding.
  Source: https://www.anthropic.com/engineering/harness-design-long-running-apps
- OpenAI's agent guide recommends setting eval baselines, defining tools well,
  using a run loop with exit conditions, preferring prompt templates before
  multi-agent complexity, and splitting agents only when instructions or tool
  overload make a single agent unreliable.
  Source: https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI's Codex Goals guide frames a goal as a durable completion contract with
  outcome, verification surface, constraints, boundaries, iteration policy, and
  blocked stop condition.
  Source: https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex
- OpenAI's agent eval docs recommend starting with traces for debugging, then
  moving to datasets and repeatable eval runs once "good" behavior is known.
  Source: https://developers.openai.com/api/docs/guides/agent-evals
- OpenAI's guardrails and human-review docs define automatic guardrails and
  human approvals as controls for whether a run should continue, pause, or stop.
  Source: https://developers.openai.com/api/docs/guides/agents/guardrails-approvals
- OpenAI's evaluation flywheel frames prompt reliability work as analyze,
  measure, improve, rather than ad hoc prompt tweaking.
  Source: https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel
- OpenAI Structured Outputs and Anthropic Structured Outputs/Strict Tool Use
  both support schema-constrained contracts for outputs or tool inputs.
  Sources:
  - https://developers.openai.com/api/docs/guides/structured-outputs
  - https://platform.claude.com/docs/en/build-with-claude/structured-outputs
  - https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use
- Anthropic Agent Skills docs describe skills as filesystem packages with
  instructions, executable code, and references loaded progressively as needed.
  Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- Anthropic skill authoring best practices emphasize concise, well-structured
  skills tested with real usage.
  Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Claude Code hooks docs distinguish deterministic lifecycle automation from
  LLM judgment: hooks can enforce actions at specific events.
  Source: https://code.claude.com/docs/en/hooks-guide
- Pi's own site says Pi is minimal and extensible through extensions, skills,
  prompt templates, themes, and packages; it explicitly says Pi skips built-in
  sub-agents and plan mode.
  Source: https://pi.dev/
- Pi skills docs describe skills as on-demand capability packages with
  progressive disclosure and `/skill:name` commands.
  Source: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md
- Pi extension docs expose lifecycle events such as `before_agent_start`,
  `agent_start`, and `agent_end`, plus system-prompt access.
  Source: https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md
- LangGraph docs position durable execution, persistence, human-in-the-loop, and
  tracing/evaluation as runtime capabilities for long-running stateful agents.
  Source: https://docs.langchain.com/oss/python/langgraph/overview
- Microsoft Agent Framework docs recommend workflows when execution order is
  well-defined, and agents when the task is open-ended or conversational. They
  also call out type-safe routing, checkpointing, and human-in-the-loop support.
  Source: https://learn.microsoft.com/en-us/agent-framework/overview/
- Google ADK docs describe predictable workflow agents, dynamic routing,
  multi-agent composition, local running, and evaluation tools.
  Source: https://docs.cloud.google.com/gemini-enterprise-agent-platform/build/adk

## Proxy-Supported Claims

- The 2026 MCP tool-description paper suggests natural-language descriptions
  materially affect tool selection and task success. This is not Pi-specific,
  but it supports treating skill/tool descriptions as part of the reliability
  surface.
  Source: https://arxiv.org/html/2602.14878v1
- DSPy supports the broader idea of modular, optimizable language-model
  programs. It is useful as inspiration for contracts and eval-driven prompt
  improvement, but adding DSPy would be overkill for this Pi-native workflow.
  Source: https://github.com/stanfordnlp/dspy
- The ReAct paper supports interleaving reasoning, action, and observation as a
  task-solving pattern. Pi already works as a tool-using coding agent, so this is
  conceptual background rather than an implementation dependency.
  Source: https://arxiv.org/abs/2210.03629
- AutoGen research supports multi-agent conversation as a viable architecture,
  but it does not justify adding an external multi-agent runtime around Pi for
  this local workflow.
  Source: https://www.microsoft.com/en-us/research/publication/autogen-enabling-next-gen-llm-applications-via-multi-agent-conversation-framework/

## Approximate Claims

- No accepted implementation recommendation depends only on approximate
  evidence. API-specific details should be rechecked before implementation.

## Blocked Claims

- None.

## Unknown Claims

- Whether Pi's current Task* tool outputs expose structured state beyond the text
  output already parsed by `tasks-till-done`.
- Whether Pi has a stable replay interface suitable for full transcript evals.
- Whether current Pi sub-agent packages are stable enough for the user's daily
  workflow.

## Rejected Or Deferred

- Adding LangGraph, Microsoft Agent Framework, Google ADK, AutoGen, or DSPy as a
  dependency is rejected for the first implementation. Those systems solve
  server-side orchestration; the user's stated goal is Pi-native composition.
- Creating many dedicated agents immediately is rejected. OpenAI's guide warns
  that multi-agent systems add complexity and overhead; the local system should
  first formalize roles, templates, and evals.
- A separate "system prompt" file is deferred. Pi already loads `AGENTS.md` and
  skills, and extensions can append small lifecycle guidance. A `SYSTEM.md`
  should be added only if a specific project needs a hard per-project prompt
  behavior that `AGENTS.md` and skills cannot express.
