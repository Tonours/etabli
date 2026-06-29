# P1 Research

## ADR Sources

- Matt Pocock keeps ADRs deliberately small: `docs/adr/NNNN-slug.md`, one short
  context/decision/why paragraph, optional status/options/consequences only when
  useful. This supports preserving the current light format.
- `adr-tools` supports `adr new -s <target>` and updates both the new and old
  ADR, including multiple superseded targets. This supports explicit
  bidirectional supersession metadata rather than relying only on prose.
- MADR has a richer template but marks metadata and most sections optional.
  This supports optional retrieval fields without making every ADR heavyweight.
- Joel Parker Henderson's ADR collection emphasizes immutability and
  superseding via a new ADR rather than editing old content.

## LLM / Retrieval Sources

- DRAFT-ing Architectural Design Decisions using LLMs says simple prompting is
  not enough and improves results with retrieved ADR examples plus few-shot or
  fine-tuning. For this repo, retrieval should be local and lightweight.
- Context Matters reports that context-aware ADR prompting improves fidelity,
  with a small recency window of about 3-5 prior ADRs balancing quality and
  efficiency; retrieval helps mainly for non-linear or cross-cutting decisions.
- LLM decision-violation work reports stronger accuracy for explicit,
  code-inferable decisions and weaker accuracy for implicit or
  deployment/organizational decisions. This argues for "cite local evidence or
  say uncertain."
- RAG research frames retrieval as a way to use explicit non-parametric memory
  with provenance. Here, `docs/adr/` is the memory; the skill must quote file
  paths/titles rather than invent context.

## Design Consequence

Do not add vector search. Use deterministic local inventory plus recent ADRs and
keyword/tag/component matching. Let Claude propose a supersession only after it
has cited candidates from disk.
