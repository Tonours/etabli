---
status: accepted
date: 2026-08-03
tags: [pi, workflow, telemetry, orchestration, simplification]
affected_components: [pi/extensions, claude/hooks, scripts, workflow, docs/adr/0007]
---

# Remove the multi-model council and the telemetry reporters

Etabli drops the five-role multi-model council (`etabli-scout`, `-analyst`,
`-challenger`, `-judge`, `-fallback`) with its `PortfolioCallState` budget
guard, and six unused workflow reporting scripts. Execution is parent-only;
`classifyMultiExecution` always returns single. Subagent delegation stays
available as an ordinary tool call, judged case by case, rather than as a routed
profile with pinned models.

## Why

The council was infrastructure sized for a team evaluation harness in a
single-operator dotfiles repo. Its own blind latency gate (2026-07-19) had
already found no quality gain, and the guard that enforced it was bypassable by
routing the same model through `general-purpose` — an incident the prior plan
records. It pinned five vendor model IDs across six files with no single source
of truth, so every provider rename was a synchronized multi-file edit that a
test suite of copy-pasted literals could not catch.

The reporters were deleted on evidence, not taste: the event ledger held **13
events total, all from 2026-07-04/05**, nothing in the month since.
`workflow/spec.md` itself requires ten task-grader outcomes before claiming
telemetry value; the bar was never cleared. `workflow-measurement-integrity`
was referenced from nowhere — until implementation proved otherwise (below).

## Scope

Kept deliberately: `scripts/workflow-event`, `scripts/lib/no-progress-guard.mjs`
and `scripts/workflow-measurement-integrity` are ledger infrastructure, not
telemetry. The no-progress mutation guard reads the ledger and names
`workflow-event` as its only escape hatch; deleting the CLI would have left a
blocker pointing at a missing tool. `workflow-retrospect` is kept as the one
remaining read-only diagnostic.

Also kept: `multi_execution_completed` remains a valid ledger event schema with
nine consumers. The council that produced it is gone; the protocol is not
retro-edited.

## Consequences

- ~11k lines removed across 117 files, including 5853 lines of untracked
  archived skill sets.
- `workflow/skills/multi-model-orchestration.md` deleted; `spec.md`,
  `contract-details.md`, `orchestration.md` and `pi/AGENTS.md` now state
  parent-only execution.
- Two Pi capabilities (`supports_subagents`, `supports_taskexecute_tracking`)
  lose their live probe with the removed smoke. They stay labelled `unknown`
  with a null `proof_command` rather than being relabelled without evidence.
- `/adversary` and `/plan-implement` keep their `pi -p` cross-model review.
  That is a different mechanism from the council and still works where a
  non-Claude runner is available.
- ADR-0007 is untouched: the deterministic router and its PLAN.md guards remain.
  Only the council layer above them is removed.

## Notes

Two findings during implementation are worth carrying forward. First, the test
baseline had been red since `d3fd845` while archived plans recorded it green —
a `prefer-ipv4-dns` test asserting a Node getter Bun does not implement. Any
"harness efficiency" figure resting on that baseline is unverified. Second,
`scripts/workflow-event` executes `workflow-measurement-integrity` on every
append, so deleting it silently broke all ledger validation; the failure
surfaced only through `-suite --strategy baseline`, not through the smoke
that was supposed to cover it.
