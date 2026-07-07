# Source-Grounded Answer Quality Research

Status: verified for the design principles, approximate for future score targets,
inconclusive for any stronger future-quality promise.

## Local Projects

### Etabli

`etabli` is the control plane: workflow contracts, router rules, validation
scripts, plan/archive discipline, adapter surfaces, and smoke tests. Its answer
quality problem is not raw memory size; it is enforcing the right loop for the
request: inspect current state, retrieve when needed, validate claims, label
uncertainty, and keep handoffs short.

### Obvault

`obvault` is the compiled memory layer: sourced documents in `docs/`, durable
wiki notes in `kb/`, and operating entrypoints in `ref/`. Its answer quality
problem is preventing weak memory from becoming trusted context. It should make
high-quality answers easier by giving agents durable, source-backed starting
points.

## External Findings

### Retrieval and memory

RAG introduced the core distinction that matters for both projects: model
parameters are not enough for current, specific, or provenance-sensitive
knowledge. External memory can make answers more specific and factual, but only
when retrieval quality and provenance are handled deliberately.

Self-RAG sharpens that into an answer policy: retrieval should be adaptive, not
automatic, and generation should be critiqued for relevance and support before
it is treated as final.

For `obvault`, this supports a compiled wiki over a blind vector database. For
`etabli`, it supports route-level rules: browse or read local memory when the
claim needs it, but do not add retrieval when the answer is already local and
stable.

### Acting, tools, and workflow

ReAct shows that reasoning and action work better when interleaved with
external sources or environments. SWE-agent shows that the interface around a
coding agent materially affects performance: commands, file editing, test
execution, and repository navigation are not neutral details.

For `etabli`, this supports keeping workflows explicit, tool surfaces
documented, and validation commands named. For `obvault`, it supports keeping
query entrypoints small and predictable.

### Durable reflection

Reflexion and Generative Agents both support the idea that memory improves
future behavior when feedback is stored and retrieved. The useful lesson is not
"save everything"; it is "save structured, reusable reflection." Raw
transcripts and low-confidence notes would make the system worse.

For `obvault`, this confirms the existing no-transcript and source/dedupe
policy. For `etabli`, it supports plan archives and event ledgers as distilled
memory instead of chat dumps.

### Evaluation and quality

OpenAI's eval guidance makes quality a repeatable engineering loop: define the
objective, collect representative cases, define metrics, run comparisons, and
iterate. Its agent-eval guidance adds traces and graders for workflow-level
questions such as tool choice, handoff, and policy violations.

Anthropic's agent guidance points in the same direction from an architecture
angle: start simple, add agentic complexity only when it measurably improves
outcomes, keep planning visible, and document/test the agent-computer
interface.

For this repo pair, "10/10" should therefore mean a quality gate and future eval
target, not a subjective claim.

### Corpus-scale questions

Contextual Retrieval and GraphRAG both highlight a limitation of simple chunk
retrieval. Exact terms, chunk context, entities, summaries, and global corpus
questions need different retrieval shapes.

For `obvault`, this suggests an upgrade path: stay with `rg` and curated wiki
notes while small; add contextual BM25/qmd/graph summaries only when questions
start failing because the corpus is too large or too global. For `etabli`, this
suggests not overbuilding search until a measured failure appears.

## Resulting Rule

Confirmed:

- Read local source of truth before answering repo/state questions.
- Browse for current, external, niche, high-stakes, or explicitly web-backed
  claims.
- Prefer a short, source-grounded answer over a long answer with weak support.
- Use `verified`, `stale`, `inconclusive`, `assumption`, `blocked`, and `not
  verified` labels when source strength matters.
- Capture reusable lessons in `obvault` only when sourced, deduped, and useful.

Rejected:

- Promise that every future answer clears a subjective maximum-quality bar.
- Add a fake automated 10/10 score without an eval dataset.
- Convert `obvault` into raw transcript storage.
- Install vector/graph tooling before a real retrieval failure justifies it.

## Sources

- https://arxiv.org/abs/2005.11401
- https://arxiv.org/abs/2310.11511
- https://arxiv.org/abs/2210.03629
- https://arxiv.org/abs/2303.11366
- https://arxiv.org/abs/2304.03442
- https://arxiv.org/abs/2405.15793
- https://arxiv.org/abs/2404.16130
- https://www.anthropic.com/engineering/building-effective-agents
- https://www.anthropic.com/engineering/contextual-retrieval
- https://developers.openai.com/api/docs/guides/evaluation-best-practices
- https://developers.openai.com/api/docs/guides/agent-evals
