# Workflow Topology (Graph Engineering Surface)

Explicit description of the Etabli control-plane topology.

This document makes the **Graph Engineering** layer first-class.
It does not change runtime behavior. The deterministic router, role contracts,
and shared state remain the source of truth. This file is the human- and
agent-readable map of that graph.

## Design principles

- A **loop** is the smallest cyclic unit (one agent/role cycle with verifier).
- A **graph** is the composition of roles, routes, and transitions with shared state.
- Nodes are contracts (skills, roles, routes), not mandatory separate processes.
- Edges are conditions (status, guards, budgets, evidence), not free-form prompts.
- Shared state travels on the edges: `PLAN.md`, event ledger, obvault, capabilities.
- Prefer the smallest subgraph that can finish with evidence.

## Shared state (the blackboard)

| Artifact | Role in the graph |
| --- | --- |
| `PLAN.md` (root) | Single active execution artifact. Status `DRAFT` → `CHALLENGED` → `READY` is the main control token. |
| `.workflow/<slug>/events.jsonl` | Durable run ledger for autonomous routes. Source of truth for resumption and retrospect. |
| `docs/plan/*.md` | Archived implemented plans (memory of completed work). |
| obvault (markdown + derived hops) | Untrusted knowledge neighborhood (1–2 hops). |
| `workflow/runtime-capabilities.json` | Honest labels for what each runtime can actually do. |
| Diff / validation output | Evidence that edges may consume before advancing. |

## Core nodes (roles / contracts)

Roles are contracts. They may run in the same process or as side-cars.

| Node | Responsibility | Typical inputs | Typical outputs / stop |
| --- | --- | --- | --- |
| **router** | Classify intent into the smallest valid route | user prompt + local state | route name + writeAllowed |
| **planner** | Produce / refresh `PLAN.md` | task + code + memory | `PLAN.md` at `DRAFT` / `CHALLENGED` / `READY` |
| **challenger** | Reject vague scope, missing checks, weak stops | `PLAN.md` | updated plan or blockers |
| **adversary** | Stress-test plan before implementation | `PLAN.md` | `READY` kept only if no blocker |
| **implementer** | Execute only a `READY` plan, minimal drift | `READY PLAN.md` | code/docs changes |
| **verifier** | Prove or reject completion from evidence | checks + artifacts | `VERIFIED` / `NOT VERIFIED` / `INCONCLUSIVE` |
| **reviewer** | Inspect correctness, regressions, safety, plan drift | diff + plan | `GO` / `GO WITH NOTES` / `BLOCK` |
| **reporter** | Leave durable state | run outcome | archive + handoff + events |
| **ops-stop** | Human checkpoint for irreversible actions | risk pattern match | risk brief, wait |

Optional multi-model nodes (adaptive, parent-only writer):

- **scout** — read-only exploration under uncertainty
- **council** — bounded parallel evaluators that join into a single verdict

## Edges (transitions)

Canonical high-level flow:

```text
user intent
    → router
        → answer                    (terminal)
        → plan-loop                 → planner → challenger → adversary
        → plan-implement            → (plan-loop) → implement (iff READY)
        → implement                 (only if root PLAN.md is READY)
        → review / verify / pr-* / sec-pr / linear-* / bug-check / ci-fix / research-plan
        → ops-stop                  (HITL)
```

Important conditional edges:

| From | Condition | To |
| --- | --- | --- |
| planner / challenger / adversary | status becomes `READY` | implementer (when route is plan-implement or implement) |
| any | destructive / secret / prod / external write-back | ops-stop |
| implementer | same hypothesis fails twice or check stays red 3× | no_progress → blocked |
| READY plan | Checks weakened without Decision Log | must demote to `CHALLENGED` (check-freeze) |
| autonomous plan-implement | no fresh-context reviewer available | blocked (request external review) |
| any autonomous route | ledger required | events.jsonl must record terminal state |

## Loop patterns as subgraphs

See `workflow/loop-patterns.md`. Each pattern is a small cyclic subgraph with a required verifier and a default cap:

- `direct`
- `localize-repair-validate`
- `react`
- `self-refine`
- `planner-builder-evaluator`
- `parallel-sections`
- `tree-search`
- `scheduled-idempotent`

Universal contract for every non-trivial loop: named goal verifier, budgets, context-reset threshold, escalation/stop, permissions.

## Multi-model subgraph

Documented in `workflow/skills/multi-model-orchestration.md`:

- Score 0 → parent only
- Material uncertainty / failure history → one route-appropriate scout
- Critical or two medium signals → bounded two-agent council with join
- Parent remains the only writer

This is a controlled fan-out / join pattern, not free multi-agent chatter.

## Knowledge subgraph (derived)

- Source of truth remains markdown in obvault.
- `scripts/graph-neighborhood` materializes 1–2 hop neighborhoods (token-capped, untrusted).
- Shadow promotion only (`scripts/obvault-shadow-promote`); no auto durable write.
- See also the derived-graph contract in `workflow/skills/obvault-memory.md`.

## Runtime adapters as thin edges

- Claude: hooks (`claude/hooks/`) + commands (`claude/commands/`)
- Pi: extensions (`pi/extensions/`) + skills (`pi/skills/`)
- Shared contracts live under `workflow/`
- Capability honesty: `workflow/runtime-capabilities.json`

Adapters must not invent primitives the host does not expose.

## Observability of the graph

- Event ledger: `workflow/events.md`
- Metrics / dossier / retrospect / monitor (read-only, experimental)
- Action-graph fixtures and smokes under `tests/`
- vNext suite as deterministic host regression of control-plane behavior

## How to evolve this topology

1. Prefer adding a mechanical guard or smoke over more prose.
2. New transverse invariant → same-change mechanical check (hook, lint, or smoke).
3. New route → update the routing table in `workflow/spec.md` and the dual adapters.
4. New multi-node pattern → document the fan-out / join conditions and budgets here.
5. Keep claims proportional to evidence labels (`confirmed` / `proxy_supported` / `blocked` / `unknown`).

## Relation to the three engineering layers

```text
Graph (this document + router + multi-role contracts + derived knowledge)
  └── Loop  (loop-patterns.md + named loops + universal contract)
        └── Harness (skills, hooks, guards, memory, telemetry, deploy, capabilities)
              └── Models (Pi / Claude)
```

This file exists so the Graph layer is no longer only implicit in code.
