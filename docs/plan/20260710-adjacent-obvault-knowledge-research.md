# Implemented: Adjacent obvault knowledge and routing coverage

## Metadata
- Archived: 2026-07-10
- Source plan: Adjacent research and routing coverage for the obvault knowledge base
- Status: IMPLEMENTED
- Commit / branch: uncommitted worktree; no publish authorization in this run

## Outcome
- Added one non-duplicative KB synthesis for indirect prompt injection, tool
  poisoning, and cross-tool trust boundaries.
- Extended existing notes for agent observability, durable execution,
  progressive tool discovery, operational memory boundaries, and Jobs to Be
  Done rather than creating parallel notes.
- Added intentional aliases/tags and seven retrieval fixtures so the dynamic
  catalog routes adjacent vocabulary without static keyword-router changes.
- Captured accepted and rejected research candidates with primary-source links
  and confidence labels.

## Context
- `/Volumes/Crucial/work/obvault/CLAUDE.md`: strict second-brain write and routing contract.
- `/Volumes/Crucial/work/obvault/docs/adjacent-knowledge-gap-research-2026-07-10.md`: source-backed gap matrix.
- `/Volumes/Crucial/work/obvault/kb/_index.md`: durable note index.
- `/Volumes/Crucial/work/obvault/_meta/evals/retrieval.tsv`: retrieval acceptance cases.

## Decisions
### Add one trust-boundary note
- Context: identity, OAuth, sandboxing, and capability boundaries were already
  covered; indirect prompt injection and untrusted cross-tool data were not.
- Choice: create `agent-input-and-tool-trust-boundaries.md`.
- Rejected options: merge it into identity/capability security; create a broad
  generic agent-security note.
- Rationale: content authority and delegated identity are related but distinct
  mechanisms with different tests.
- Consequences: prompt-injection, tool-poisoning, and MCP trust vocabulary now
  route to an explicit execution contract.

### Extend existing notes for adjacent vocabulary
- Context: observability, durable execution, memory, and JTBD overlapped notes
  already in the compiled wiki.
- Choice: add focused sections, sources, aliases, tags, and backlinks.
- Rejected options: four new topical notes; static router keyword mappings.
- Rationale: dynamic metadata routing already rebuilds on every call and the
  vault contract prefers updating existing notes.
- Consequences: the KB remains compact while natural-language prompts load the
  relevant compiled knowledge.

### Keep emerging standards lifecycle-sensitive
- Context: OpenTelemetry GenAI semantic conventions moved to a dedicated
  repository and remain evolving.
- Choice: retain the architectural observability pattern while requiring
  current field/stability verification before implementation.
- Rejected options: pin current attribute names as durable facts.
- Rationale: preserves useful interoperability knowledge without creating a
  stale implementation contract.
- Consequences: future implementations must consult the current spec.

## Accepted Drift
- Original plan/spec: representative routing prompts should match the new
  vocabulary.
- Implemented reality: the first durable-agent prompt variant abstained because
  it did not contain a complete catalog phrase.
- Why accepted: the code-diff adversary exposed the variant; the bounded
  `durable agent` alias fixed it without changing router code, and validation
  was rerun.

## Validation Evidence
- `scripts/research-proof-check /Volumes/Crucial/work/obvault/docs/adjacent-knowledge-gap-research-2026-07-10.md`
  - result: `research proof check: ok`.
- `_meta/validate-kb.sh`
  - result: strict validation passed with 28 notes.
- `_meta/obvault eval --suite retrieval`
  - result: 33 cases, hit@5 1.0, MRR@5 0.9624, exclusions 2/2.
- `_meta/tests/run.sh`
  - result: retrieval, 11/11 security, distillation, and routing suites passed.
- Representative `_meta/obvault route --json` prompts
  - result: trust boundaries, observability, durable-agent recovery,
    progressive MCP discovery, agent memory, and JTBD routed to intended notes.
- `git diff --check`
  - result: passed for obvault and Etabli.
- Fresh-context reviewer `019f4aeb-eafa-7ec1-bda6-a1ffdb779938`
  - result: `GO WITH NOTES`; no content or routing blocker.
- Code-diff adversary `019f4aec-eea0-78e2-8547-d5323c6c2f9c`
  - result: `GO WITH NOTES`; only routing variant fixed and revalidated.

## Follow-up State
- Remaining risks: GenAI semantic-convention fields can change; broad natural
  language beyond catalog phrases still depends on the current lexical router.
- Parking lot: consider semantic/fuzzy catalog matching only if future feedback
  shows repeated real misses; do not preemptively multiply aliases.
- Superseded docs/specs: none.
- Next links: obvault research artifact and the new trust-boundary note.
