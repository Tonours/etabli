# Cross-Project Research Grounding

Status: verified for current local file evidence and cited source existence,
approximate for future architecture choices, not verified for global future
answer quality.

Access date: 2026-07-07.

## Purpose

This dossier maps the two active local projects to the external research and
articles that justify their current design:

- `etabli`: the agent workflow control plane.
- `obvault`: the strict second brain and compiled knowledge layer.

It exists so future answers can start from a maintained project map instead of
rediscovering the relationship between workflow, memory, retrieval, validation,
and answer quality.

## Local System Map

| Project | Local role | Primary local evidence | What it should optimize |
| --- | --- | --- | --- |
| Etabli | Workflow/control plane for Codex, Pi, Claude, repo checks, plans, routes, and handoffs. | `workflow/spec.md`, `workflow/answer-quality.md`, `scripts/answer-quality-audit`, `tests/workflow-docs-smoke.sh` | Evidence-first execution, minimal route selection, auditable validation, and safe handoff boundaries. |
| obvault | Durable personal knowledge base with source, compiled wiki, reference, and validation layers. | `/Volumes/Crucial/work/obvault/CLAUDE.md`, `/Volumes/Crucial/work/obvault/ref/second-brain-operating-model.md`, `/Volumes/Crucial/work/obvault/kb/_index.md`, `/Volumes/Crucial/work/obvault/_meta/validate-kb.sh` | Reusable sourced knowledge, dedupe, wikilinks, no raw transcript storage, and query-first entrypoints. |

## External Grounding Matrix

| Source | Relevant finding | Etabli implication | obvault implication |
| --- | --- | --- | --- |
| Karpathy LLM Wiki gist, https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f | A useful LLM-maintained wiki is a persistent, compounding Markdown artifact with raw sources, wiki pages, and schema instructions. | Keep project workflow contracts explicit and versioned so agents know how to maintain artifacts. | Keep `docs/` as sources, `kb/` as compiled wiki, and `CLAUDE.md`/`AGENTS.md` as schema. |
| Anthropic, Building Effective Agents, https://www.anthropic.com/engineering/building-effective-agents | Start simple, add agentic complexity only when it improves outcomes, keep planning visible, and make tool interfaces clear. | Prefer deterministic routes, `PLAN.md`, smoke tests, and explicit tools before larger autonomous mechanisms. | Prefer plain Markdown, `rg`, index notes, and validators before vector/graph infrastructure. |
| OpenAI eval best practices, https://developers.openai.com/api/docs/guides/evaluation-best-practices | Quality should be treated as an eval loop with representative examples and metrics. | `answer-quality-eval` and fixture manifests are the right floor for regression protection. | Durable memory should record validated lessons and gaps, not subjective quality claims. |
| OpenAI agent evals, https://developers.openai.com/api/docs/guides/agent-evals | Agent quality includes tool choice, traces, policy following, and workflow behavior. | Saved traces under `docs/answer-quality-traces/` are necessary evidence beyond prose. | Important obvault-backed answers should become traceable durable notes only when sourced. |
| RAG, https://arxiv.org/abs/2005.11401 | External memory improves provenance-sensitive and knowledge-intensive answers relative to parametric memory alone. | Repo answers should inspect local source of truth and browse when facts are unstable. | The vault should act as explicit non-parametric memory with sources and update paths. |
| Self-RAG, https://arxiv.org/abs/2310.11511 | Retrieval should be adaptive and critiqued, not blindly applied. | Do not browse or load vault context when the answer is local and stable; do retrieve when support is needed. | Prefer no note or no claim over weakly supported memory; validate support before finalizing. |
| GraphRAG, https://arxiv.org/abs/2404.16130 | Global corpus questions can need entity/community summaries rather than local chunk retrieval alone. | Add graph/global summarization only after a measured failure of current docs and search. | Keep the option open for graph summaries, but current scale supports curated wiki pages first. |
| SWE-agent ACI, https://arxiv.org/abs/2405.15793 | Agent-computer interface design affects software-engineering agent performance. | Commands, routes, hooks, smoke tests, and archive rules are product surface for agents, not incidental scripts. | Query order, index shape, and validators are the agent-computer interface for memory. |

## Project Analysis

### Etabli

Status: verified for local architecture.

Etabli is strongest where it turns vague agent behavior into inspectable
contracts: one active `PLAN.md`, `READY` gates, event ledgers, deterministic
router fixtures, smoke tests, answer-quality helpers, and implemented-plan
archives. This matches the external guidance favoring transparent workflows,
clear tool interfaces, and eval-driven iteration.

The main risk is process weight. The correct response is not to add more
ceremony everywhere; it is to keep the smallest route that can finish with
evidence, and only add mechanical checks when repeated failures justify them.

### obvault

Status: verified for local architecture.

obvault implements the LLM-wiki pattern in a conservative local form:
source/corpus material in `docs/`, compiled reusable notes in `kb/`, operating
entrypoints in `ref/`, and shell validation in `_meta/`. This is a good match
for a personal second brain because it creates a maintained artifact between
raw sources and chat answers.

The main risk is weak memory becoming trusted context. The correct response is
strict source requirements, index hygiene, wikilink validation, no raw
transcripts, and uncertainty labels in answers.

## Combined Operating Rule

Confirmed:

- Use Etabli to decide the route, validation, and safety boundary.
- Use obvault to retrieve durable knowledge only after reading its entrypoints.
- Browse the web for current, external, niche, high-stakes, or explicitly
  requested source claims.
- Save durable lessons only when they are sourced, deduped, reusable, and pass
  local validation.
- Treat answer quality as a floor plus trace corpus, not as a universal future
  score.

Not verified:

- Future live-answer quality across all task types.
- Whether vector search, qmd, or graph summaries are needed at current vault
  scale.
- Whether cloud automation should be added; that still needs explicit account,
  token, and external-write authorization.

## Practical Answer Policy

For future answers that touch these projects:

1. Inspect current local files before relying on prior memory.
2. Use obvault query order for memory-backed questions:
   `ref/second-brain-operating-model.md`, `kb/_index.md`, then `kb/` and `ref/`.
3. Use web sources when the answer depends on external or unstable facts.
4. Report validation commands and results when edits or state claims matter.
5. Label remaining gaps as `not verified`, `inconclusive`, `blocked`,
   `approximate`, or `assumption`.
6. Keep final answers short unless the user asks for a deep report.

## Sources

- https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
- https://www.anthropic.com/engineering/building-effective-agents
- https://developers.openai.com/api/docs/guides/evaluation-best-practices
- https://developers.openai.com/api/docs/guides/agent-evals
- https://arxiv.org/abs/2005.11401
- https://arxiv.org/abs/2310.11511
- https://arxiv.org/abs/2404.16130
- https://arxiv.org/abs/2405.15793
- `/Volumes/Crucial/work/etabli/workflow/spec.md`
- `/Volumes/Crucial/work/etabli/workflow/answer-quality.md`
- `/Volumes/Crucial/work/obvault/CLAUDE.md`
- `/Volumes/Crucial/work/obvault/ref/second-brain-operating-model.md`
