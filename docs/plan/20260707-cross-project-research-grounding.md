# Implemented: Cross-project research grounding

## Metadata
- Archived: 2026-07-07
- Source plan: cross-project research grounding map
- Status: IMPLEMENTED
- Commit / branch: branch `main`; commit pending

## Outcome
- Added `docs/cross-project-research-grounding.md` as the Etabli-side dossier
  mapping `etabli` and `obvault` to local evidence, external sources,
  implications, and remaining gaps.
- Added `/Volumes/Crucial/work/obvault/kb/etabli-obvault-project-grounding.md`
  as the obvault durable synthesis.
- Linked the new obvault synthesis from `kb/_index.md` and `ref/current-work.md`.
- Pinned the Etabli dossier in `tests/workflow-docs-smoke.sh` and
  `scripts/answer-quality-audit`.

## Context
- `workflow/spec.md` is the Etabli control-plane contract.
- `workflow/answer-quality.md` is the answer-quality contract.
- `/Volumes/Crucial/work/obvault/CLAUDE.md` defines obvault as a strict second
  brain, not raw transcript storage.
- `/Volumes/Crucial/work/obvault/ref/second-brain-operating-model.md` defines
  the obvault capture, distill, link, index, query, and validate loop.
- External grounding used:
  - https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
  - https://www.anthropic.com/engineering/building-effective-agents
  - https://developers.openai.com/api/docs/guides/evaluation-best-practices
  - https://developers.openai.com/api/docs/guides/agent-evals
  - https://arxiv.org/abs/2005.11401
  - https://arxiv.org/abs/2310.11511
  - https://arxiv.org/abs/2404.16130
  - https://arxiv.org/abs/2405.15793

## Decisions
### Add a cross-project map instead of another single-topic note
- Context: Existing docs covered answer quality and obvault architecture, but
  no durable artifact mapped the two repos as one system.
- Choice: Add one Etabli dossier plus one obvault synthesis.
- Rejected options: A broad manifesto; another answer-quality-only note.
- Rationale: Future answers need the relationship between workflow control and
  durable memory, not another isolated summary.
- Consequences: The new map is discoverable from README, smoke tests, audit,
  and obvault index.

### Keep retrieval/tooling upgrades deferred
- Context: Karpathy LLM Wiki and GraphRAG both justify richer search and
  summary structures at scale.
- Choice: Record qmd/vector/graph tooling as future options only.
- Rejected options: Install search or cloud tooling now.
- Rationale: Current validation does not show a measured retrieval failure.
- Consequences: The system stays simple and local while preserving an upgrade
  path.

## Accepted Drift
- Original plan/spec: Use fresh-context review for autonomous runs when
  explicitly authorized.
- Implemented reality: Same-context scoped diff review found no plan drift; no
  fresh-context reviewer was launched because this active continuation did not
  include explicit delegation/subagent authorization.
- Why accepted: The changes were documentation/check pins, fully covered by
  deterministic validation, and no external write action occurred.

## Validation Evidence
- command: `scripts/research-proof-check docs/cross-project-research-grounding.md`
  - result: passed with `research proof check: ok`
- command: `scripts/answer-quality-check --mode research docs/cross-project-research-grounding.md`
  - result: passed with `answer quality check: ok`
- command: `scripts/answer-quality-audit --obvault /Volumes/Crucial/work/obvault`
  - result: passed with `answer quality audit: ok`
- command: `(cd /Volumes/Crucial/work/obvault && _meta/validate-kb.sh)`
  - result: passed with `validate-kb: ok`
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed with `workflow docs smoke test: ok`
- command: `git diff --check`
  - result: passed in Etabli
- command: `(cd /Volumes/Crucial/work/obvault && git diff --check)`
  - result: passed
- command: `scripts/workflow-event validate cross-project-research-grounding`
  - result: passed with `28 events, ok` after archive, cleanup, and completion

## Follow-up State
- Remaining risks: Future live-answer quality is still not verified across
  enough real traces; the active goal remains broader than this tranche.
- Parking lot: Add trace examples from real repo explanations, obvault-backed
  answers, and source-backed research handoffs; consider search tooling only
  after a measured retrieval failure.
- Superseded docs/specs: none.
- Next links:
  - `docs/cross-project-research-grounding.md`
  - `/Volumes/Crucial/work/obvault/kb/etabli-obvault-project-grounding.md`
  - `workflow/answer-quality.md`
