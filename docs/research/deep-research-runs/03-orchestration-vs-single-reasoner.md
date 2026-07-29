# Research result

**Status: Partial**

Multi-agent or named workflow-graph orchestration improves software-engineering agent outcomes only when work is high-value, breadth-first, and largely independent—especially parallel read-heavy exploration, multi-axis review, or verifier loops with clear criteria—while a single strong reasoner plus deterministic guards remains the better default for most coding write paths. Parallel co-editing and dense real-time coordination usually hurt quality and economics; gains often vanish once token cost, latency, and inter-agent conflict are counted. The transferable pattern is one parent control plane: parent-only mutation, isolation subagents that return summaries, budgets, idempotent external effects, and mechanical verification—not a second harness stack or permanent swarm.

### When multi-agent structure helps
Increase complexity only after single-call or simple workflow designs fall short; then match the pattern to the failure mode. Orchestrator–worker graphs fit when subtasks cannot be pre-specified; evaluator–optimizer loops fit when evaluation criteria are clear and iterative gain is measurable; sectioning or voting fits independent subtasks or multi-perspective verification.[S2]

Outcomes improve mainly on high-value breadth-first work with heavy independent parallelization, information beyond one context window, and many complex tools—not when agents must share the same context or maintain many real-time dependencies.[S1] In SE practice, named/subagent orchestration pays when the goal is context isolation and parallel read-heavy work (exploration, tests/logs, triage, multi-axis review) that returns summaries to a main decision thread.[S4] Specialized roles help when modular separation combines complementary capabilities—code suggestion versus execution, human validation, multi-perspective review—rather than identical peers freely co-authoring the same mutable state.[S5]

In production harnesses that already run a strong parent with deterministic guards, multi-agent or council graphs should stay gated to bounded independent subtasks or verification phases where separate evaluators materially improve evidence, keeping the critical write path local.[S6]

### When multi-agent hurts
Most coding has fewer truly parallelizable tasks than research; domains that force shared context and dense inter-agent dependencies are a poor fit today because agents remain weak at real-time coordination and delegation.[S7][S1] On software-engineering write paths, parallel multi-agent graphs often worsen outcomes relative to a single continuous reasoner: subagents make conflicting implicit decisions, and reliable practice favors continuous context with isolation-style subagents that answer well-scoped questions rather than parallel co-editing.[S3]

Without concurrency control, multiple writers on shared artifacts produce lost updates, stale-state work, silent overwrites, and cascades built on wrong intermediate code—failure modes isolation-only (single-writer) designs avoid.[S11] Decorative multi-agent fan-out and multi-hop pipelines can add large latency without quality gain and can succeed hop-locally while failing end-to-end; favor one reasoner plus bounded, non-writing or isolation-only subagents.[S12]

Multi-agent systems impose a large token and latency tax—on the order of ~15× chat token use in reported multi-agent research—so they hurt economics unless task value covers the overhead; agentic systems generally trade cost and latency for performance.[S8] Across popular multi-agent frameworks, end-to-end failure is common (reported 41%–86.7% on seven SOTA open-source MAS), and gains over single-agent or simple baselines are often minimal.[S9] Failure modes cluster into system-design issues (~44%), inter-agent misalignment (~32%), and weak task verification (~23%)—including step repetition, role/task disobedience, failure to seek clarification, reasoning–action mismatch, and premature, incomplete, or incorrect verification (often superficial checks that miss high-level correctness).[S10]

Architectures should start with the lowest complexity that works; multi-agent orchestration is justified only when a single agent cannot reliably handle specialization, security boundaries, or parallel work, because multi-agent adds coordination overhead, latency, and failure modes.[S15]

### Minimum control plane (one harness)
A control plane is governance over coordination—pre-execution policy at every delegation or tool boundary, approval gates, fleet-wide budget limits, and an immutable audit trail—without replacing the agent framework itself.[S13] Production systems need hard mechanisms: single-writer or leases, idempotent tools with dedup keys, verifier checkpoints, and step/token/retry budget caps so failures fail safe rather than cascade or double-effect.[S14]

For multi-agent coding, treat as prerequisites: isolation (e.g. per-agent worktrees), one-owner file mutation, verification gates (plan approval, post-task tests/hooks), and hard per-agent token/iteration kill criteria; verification—not generation—is the bottleneck.[S16]

Under one product harness, subagents should be parent-orchestrated workers for isolation and context: the main agent keeps requirements and decisions; specialized subagents run parallel noisy work and return summaries; the parent spawns, routes follow-ups, waits, and closes threads—preferring read-heavy parallel work and caution on parallel write-heavy edits.[S19] Those subagents share the parent control plane (sandbox, permission mode, live parent overrides)—not a separately governed second harness—though spawn config may layer model/sandbox/MCP/skills overrides.[S20] Long-running multi-step work can remain a single-thread completion contract (persistent objective, budget, evidence-based completion, anti-spin continuation) rather than multi-agent orchestration.[S21] Production coding harnesses similarly frame subagents as parent-session side contexts with isolation and tool limits that return summaries; multi-session patterns (background agents, agent teams) are a separate class and should not be collapsed into the single-reasoner baseline without flagging.[S22]

A concrete one-harness multi-model contract: parent-only writing, parent-owned result consolidation (no majority vote), deterministic checks over model judgments, bounded budgets/caps, and isolation of sidecars from shared-tree mutation—without a separate ambient multi-agent graph stack; ordinary work and mutation stay parent-only after automatic full panels failed a latency/quality tradeoff.[S17][S6] Net progress does not require a second general orchestration or harness layer: keep a thin evidence-first control plane (one writer, READY gates, ledgers, mechanical checks) and reject permanent multi-agent swarms and framework rewrites without outcome proof.[S18]

### Claims that assume a second full harness stack
Flag as second-stack (or second control-plane) assumptions: multi-agent ownership handoffs that transfer control away from the orchestrator; agent frameworks or named workflow graphs as architecture; extra full agent harness trees; and quality lifts from hop count alone. The transferable pattern is parent-only writer plus bounded isolation subagents under one adapter/control plane—not handoffs that cede ownership, parallel harness trees, or ambient multi-agent graphs.[S24]

Anthropic’s research multi-agent product (orchestrator–worker under one feature, large token cost, strong gains on breadth-first independent search) is domain-specific: most coding tasks are explicitly a poor multi-agent fit, so treating those research gains as a general SE multi-agent baseline against single-reasoner coding is a domain/stack transfer assumption to reject without independent verification.[S23]

## Sources
- [S1] [S23] "How we built our multi-agent research system (Anthropic Engineering)" — "https://www.anthropic.com/engineering/multi-agent-research-system"
- [S2] "Building effective agents (Anthropic Engineering)" — "https://www.anthropic.com/engineering/building-effective-agents"
- [S3] "Don’t Build Multi-Agents (Cognition)" — "https://cognition.com/blog/dont-build-multi-agents"
- [S4] "Subagents (OpenAI Codex / ChatGPT Learn docs)" — "https://learn.chatgpt.com/docs/agent-configuration/subagents"
- [S5] "AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation (arXiv:2308.08155)" — "https://arxiv.org/abs/2308.08155"
- [S6] "Etabli Orchestration Contract + multi-model-orchestration.md" — "/Users/tonours/work/etabli/workflow/skills/orchestration.md"
- [S7] "How we built our multi-agent research system (Anthropic)" — "https://www.anthropic.com/engineering/multi-agent-research-system"
- [S8] "How we built our multi-agent research system; Building effective agents" — "https://www.anthropic.com/engineering/multi-agent-research-system"
- [S9] "Why Do Multi-Agent LLM Systems Fail? (MAST / NeurIPS 2025 Datasets & Benchmarks)" — "https://arxiv.org/abs/2503.13657"
- [S10] "Why Do Multi-Agent LLM Systems Fail? (MAST taxonomy)" — "https://arxiv.org/pdf/2503.13657"
- [S11] "Multi-Agent Systems Have a Distributed Systems Problem" — "https://christophermeiklejohn.com/ai/agents/distributed/zabriskie/2026/03/30/multi-agent-systems-have-a-distributed-systems-problem.html"
- [S12] "Pi Adaptive Multi-Model Orchestration; single-reasoner-over-multi-agent-pipeline (obvault)" — "/Users/tonours/work/etabli/workflow/skills/multi-model-orchestration.md"
- [S13] "Multi-Agent Orchestration: Why You Need a Control Plane" — "https://cordum.io/blog/multi-agent-orchestration-control-plane"
- [S14] "Multi-Agent Orchestration: Architecture Patterns for Agents That Don't Step on Each Other" — "https://apptad.com/insights/multi-agent-orchestration-architecture-patterns/"
- [S15] "AI Agent Orchestration Patterns - Azure Architecture Center" — "https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns"
- [S16] "The Code Agent Orchestra - what makes multi-agent coding work" — "https://addyosmani.com/blog/code-agent-orchestra/"
- [S17] "Pi Adaptive Multi-Model Orchestration" — "/Users/tonours/work/etabli/workflow/skills/multi-model-orchestration.md"
- [S18] "Etabli  goal research / leap baseline" — "/Users/tonours/work/etabli/docs/etabli--goal-research.md"
- [S19] "Codex Subagents (OpenAI / ChatGPT Learn)" — "https://learn.chatgpt.com/docs/agent-configuration/subagents"
- [S20] "Codex Subagents — Approvals, sandbox, custom agents" — "https://learn.chatgpt.com/docs/agent-configuration/subagents"
- [S21] "Using Goals in Codex (OpenAI Cookbook)" — "https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex"
- [S22] "Create custom subagents (Claude Code Docs)" — "https://code.claude.com/docs/en/sub-agents"
- [S24] "Agents SDK migration; Building effective agents; Etabli leap research prompts/baseline" — "https://developers.openai.com/cookbook/examples/agents_sdk/migrate-from-claude-agent-sdk/readme ; https://www.anthropic.com/engineering/building-effective-agents ; /Users/tonours/work/etabli/docs/research/20260729-etabli-leap-deep-research-prompts.md ; /Users/tonours/work/etabli/docs/research/20260729-etabli-leap-baseline.md ; /Users/tonours/work/etabli/workflow/skills/multi-model-orchestration.md" (independently checked against "Agents SDK migration; Building effective agents; Etabli leap research prompts/baseline" — "https://developers.openai.com/cookbook/examples/agents_sdk/migrate-from-claude-agent-sdk/readme")

## Coverage and uncertainty
- "Question 1 uncertainty: No inspected primary source gives a universal quantitative SE win-rate for multi-agent graphs vs a single strong reasoner under identical models, tools, and token budgets; Anthropic’s +90.2% figure is an internal research eval, not a coding benchmark."
- "Question 1 uncertainty: Symphony/Codex goal-oriented board orchestration was only partially retrieved in this pass; claims about always-on issue-tracker agent fleets are not included without fuller primary inspection."
- "Question 1 uncertainty: AutoGen’s paper demonstrates effectiveness across domains including coding but does not, in the inspected abstract/intro sections, isolate the exact task conditions where multi-agent beats a single strong agent with deterministic guards under matched cost."
- "Question 2 uncertainty: No inspected controlled SWE-bench-style RCT directly proves a universal score drop for peer/graph multi-agent vs single strong reasoner across all coding agents; the strongest coding-specific caveat is Anthropic’s qualitative domain-fit statement plus MAST coding-framework traces."
- "Question 2 uncertainty: Meiklejohn evidence is practitioner primary (production multi-Claude Code) and distributed-systems analogy, not a multi-benchmark measurement study."
- "Question 2 uncertainty: Obvault ZS multi-agent post-mortem is secondary capture of a conference talk; exact quantitative metrics of the original pipeline were not re-verified from a primary transcript in this pass."
- "Question 2 uncertainty: MAST percentages are prevalence among labeled failure modes in their annotated traces, not causal effect sizes of multi-agent vs single-agent on identical SE tasks."
- "Question 3 uncertainty: No inspected primary source proves a unique, globally necessary and sufficient minimum set of control-plane properties that guarantees multi-agent SE work is always net-positive; claims describe prescribed properties and local harness decisions, not a universal optimality proof."
- "Question 3 uncertainty: Cordum and Apptad are practitioner/vendor architecture essays, not controlled experiments measuring ROI of each control-plane property in isolation."
- "Question 3 uncertainty: Whether named workflow graphs (e.g. pi-workflow) add value over route-based control planes without dual-harness complexity remains explicitly open in Etabli’s G10 gap, with no confirmed adoption proof in the inspected files."
- "Question 3 uncertainty: Idempotent external effects are strongly recommended in secondary orchestration writeups; the inspected Microsoft and Etabli multi-model docs emphasize validation, isolation, and budgets more than formal tool idempotency contracts."
- "Question 4 uncertainty: No completed Pass B deep-research artifact exists yet for prompt 3 (simple orchestration vs multi-agent graphs) under docs/research/deep-research-runs/; only runs 01 and 02 are present."
- "Question 4 uncertainty: Codex docs caution parallel writes and offer read-only custom agents but do not document OS/file locks or a hard single-writer kernel across subagents—whether production enforces more than sandbox inheritance remains unstated."
- "Question 4 uncertainty: Claude 'agent teams' / multi-session coordination and Codex custom agents that override full session config (MCP, skills, model) sit on a spectrum; they remain same-product features but can behave like second control planes relative to a pure single-reasoner baseline."
- "Question 4 uncertainty: Anthropic’s 90.2% multi-agent research eval lift is internal and research-domain; quantitative transfer to coding-agent harnesses is not directly evidenced in the inspected primary sources."
- "Question 4 uncertainty: Live interactive Codex goal/subagent behavior and live Claude Agent-tool proof remain labelled unknown/opt-in in the local Etabli capability matrix; offline docs do not prove every host build wires identical enforcement."
