# Implemented: Etabli graph-engineering ready + solid harness scorecard

## Metadata
- Archived: 2026-07-24
- Source plan: Graph-engineering ready + solid harness scorecard
- Status: IMPLEMENTED
- Commit / branch: main (uncommitted)

## Outcome
- Derived-graph contract documented and smoked in `workflow/skills/obvault-memory.md`.
- Neighborhood pack helper `scripts/graph-neighborhood` (1–2 hops, token cap, untrusted, markdown-canonical).
- Multi-hop fixture vault + smokes; ≥2  tasks (one-hop, stale-label, hops=2).
- Shadow-only promotion helper `scripts/obvault-shadow-promote` (no durable kb write, no --apply).
- Action-graph fixture from real router ops-stop/READY cases.
- Episodic ledger samples with stable refs validate under schema v2.
- Harness scorecard: verify-agentic-infra all,  35/35, capabilities honest, git diff --check.

## Decisions
### Derived graph not Neo4j
- Context: industry GraphRAG pressure
- Choice: markdown-canonical + derived wikilink hops
- Rejected: Neo4j/Graphiti/vector DB day-1
- Rationale: local-first ADR + existing obvault design

### Default hops=1, max=2
- Choice: MVC default 1-hop; hops=2 when multi-hop needed
- Evidence: graph-neighborhood-smoke differential

### Shadow-only bridge
- Choice: dry-run payload helper only
- Rejected: auto distill --apply

## Validation Evidence
- tests/graph-contract-smoke.sh: ok
- tests/graph-neighborhood-smoke.sh: ok
- tests/action-graph-smoke.sh: ok
- tests/obvault-shadow-promote-smoke.sh: ok
- scripts/-suite: 35/35
- scripts/verify-agentic-infra all: exit 0
- git diff --check: exit 0

## Follow-up State
- Remaining risks: live multi-hop against real vault not re-proven here (fixture isolation intentional); expand-2 optional path exists; ~123 stale kb notes out of scope.
- Next links: workflow//results/expand-decision.txt; tests/fixtures/action-graph.tsv
