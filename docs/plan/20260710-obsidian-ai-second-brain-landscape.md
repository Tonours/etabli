# Implemented: Source-tiered Obsidian and AI second-brain landscape

## Metadata
- Archived: 2026-07-10
- Source plan: Comprehensive Obsidian and AI second-brain landscape research
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome
- Compiled a comprehensive, source-tiered Obsidian/AI landscape into obvault.
- Updated the existing second-brain architecture and capture notes before
  creating one non-duplicative integration-boundary synthesis.
- Added English and French routing vocabulary for Obsidian AI, CLI, Headless,
  Bases, Web Clipper Interpreter, plugin, and MCP questions.
- Kept Twitter/X posts and captioned videos as discovery or workflow signals,
  below official documentation and primary repositories.
- Recorded the user's future preference for authenticated Twitter/X research
  through the connected Chrome session without storing account data.

## Context
- `/Volumes/Crucial/work/obvault/CLAUDE.md`: strict `docs/` evidence, `kb/`
  compiled knowledge, and `ref/` entrypoint contract.
- `/Volumes/Crucial/work/obvault/docs/obsidian-ai-second-brain-landscape-2026-07-10.md`:
  evidence tiers, architecture, ecosystem sample, security, and recommendations.
- `/Volumes/Crucial/work/obvault/kb/obsidian-ai-integration-boundaries.md`:
  durable choice matrix for filesystem skills, CLI, Headless, capture AI,
  plugins, and MCP.

## Decisions
### Keep Markdown and Git canonical
- Context: Obsidian exposes several interfaces over local Markdown.
- Choice: treat Bases and agent integrations as views or access lanes, not new
  sources of truth.
- Rejected options: plugin-first architecture, cloud-first automation, and raw
  transcript dumps.
- Rationale: portability, inspectable diffs, bounded writes, and recovery.
- Consequences: every automation remains source-backed and validation-gated.

### Separate integration lanes by authority
- Context: CLI, Headless, community plugins, MCP, and direct filesystem access
  have different runtime and security properties.
- Choice: select the least-authorized lane that satisfies the use case.
- Rejected options: autonomous bulk writes, generic command escape hatches, and
  desktop CLI/Headless conflation.
- Rationale: reduce data disclosure, prompt-injection impact, and sync damage.
- Consequences: plugin/MCP pilots start read-only on a clone; Headless requires
  backup, sync-mode, conflict, and recovery tests.

### Use a hybrid retrieval model
- Context: creator material sometimes framed compiled wikis as replacing RAG.
- Choice: compile stable knowledge and retain exact, metadata, backlink,
  lexical, and optional semantic retrieval for long-tail or volatile evidence.
- Rejected options: categorical "better than RAG" claims.
- Rationale: the two mechanisms solve different lifecycle problems.
- Consequences: embeddings remain an evidence-driven later optimization.

## Accepted Drift
- Original plan/spec: preserve exact observed project popularity metrics.
- Implemented reality: removed star counts after fresh review showed same-day
  drift; retained dated activity and license metadata with a volatility warning.
- Why accepted: exact popularity does not improve the adoption decision and is
  not reproducible enough for durable knowledge.

## Validation Evidence
- command: `/Volumes/Crucial/work/obvault/_meta/validate-kb.sh`
  - result: strict validation passed for 29 notes.
- command: `/Volumes/Crucial/work/obvault/_meta/obvault sources --check --resolve-local`
  - result: 196 sources resolved.
- command: `/Volumes/Crucial/work/obvault/_meta/obvault eval --suite retrieval`
  - result: 46 cases, Hit@5 1.0, MRR@5 0.984848, abstentions 2/2.
- command: `/Volumes/Crucial/work/obvault/_meta/tests/run.sh`
  - result: schema, manifest, retrieval, security, distillation, and routing
    suites passed.
- command: `scripts/research-proof-check` and `scripts/answer-quality-check --mode research`
  - result: both passed for the new landscape artifact.
- command: `scripts/answer-quality-audit --obvault /Volumes/Crucial/work/obvault`
  - result: passed.
- command: representative `_meta/obvault route --json` prompts
  - result: Obsidian AI, Headless, MCP/plugin, and Web Clipper prompts routed to
    the intended durable notes.
- command: fresh `codex exec --ephemeral --sandbox read-only` review
  - result: PASS; no blocker or unjustified duplicate found.
- command: `git diff --check` in obvault and Etabli
  - result: passed.

## Follow-up State
- Remaining risks: Obsidian open-beta and plugin/project capabilities remain
  time-sensitive; review on or before each note's `review_after` date.
- Parking lot: add paraphrased route-level fixtures if real usage produces
  misses; evaluate embeddings only from measured retrieval failures.
- Superseded docs/specs: none.
- Next links: `kb/llm-wiki-second-brain-architecture.md`,
  `kb/obsidian-ai-integration-boundaries.md`, and
  `kb/second-brain-source-capture.md` in obvault.
