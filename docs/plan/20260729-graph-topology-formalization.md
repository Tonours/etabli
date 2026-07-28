# Implemented: Graph topology formalization

## Metadata
- Archived: 2026-07-29
- Source: Conversation-driven hardening after harness/loop/graph analysis
- Status: IMPLEMENTED (documentation + formalization only)
- Branch: feat/graph-topology-formalization-20260729

## Goal
Make the Graph Engineering layer of Etabli explicit without changing runtime behavior.

## Outcome
- Added `workflow/topology.md` — first-class map of nodes (roles/contracts), edges (conditions), shared state, loop subgraphs, multi-model fan-out/join, and derived knowledge graph.
- This plan archive records the decision and scope.

## Scope
### In scope
- Explicit topology document
- Mapping of existing router, roles, loops, multi-model, and obvault derived graph
- Clear layering statement (Harness → Loop → Graph)

### Out of scope / Non-goals
- No change to router logic, hooks, or Pi extensions
- No new runtime state machine engine
- No Neo4j / external graph database
- No auto-apply or new autonomous loops
- No modification of READY / check-freeze / ops-stop mechanics (already covered by prior audit fixes)

## Approach
Documentation-first formalization. The current system already behaves as a graph of contracts and guards. Making the topology readable reduces implicit knowledge and prepares future mechanical improvements (declarative fan-out, action-graph as runtime source of truth, etc.) without increasing blast radius.

## Validation
- File added under `workflow/` (same surface as other contracts)
- No runtime path changed → existing `scripts/verify-agentic-infra` and smokes remain the baseline
- Claims stay proportional: this is a map, not a new execution engine

## Follow-up (optional next slices)
1. Reference `workflow/topology.md` from `workflow/spec.md` and `AGENTS.md`
2. Emit a simple Mermaid or machine-readable dump of the topology for retrospect
3. Treat action-graph + events ledger more explicitly as the live path through the topology
4. Declarative fan-out/join budgets for multi-model council (still parent-only writer)

## Decision Log
- 2026-07-29: Chose pure formalization over runtime changes. Prior P0/P1 from the 2026-07-24 harness audit (check-freeze mechanical helper, READY asymmetry notes, etc.) were already addressed in subsequent work; the remaining high-leverage gap was making Graph Engineering visible.
