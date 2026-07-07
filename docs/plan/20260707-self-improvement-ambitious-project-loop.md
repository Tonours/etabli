# Implemented: Self-improvement and ambitious project loops

## Metadata
- Archived: 2026-07-07
- Source plan: Etabli self-improvement and ambitious project delivery capability
- Status: IMPLEMENTED
- Commit / branch: `main` at `ab39b30`; changes are uncommitted

## Outcome
- Added `workflow/skills/self-improvement-loop.md`, a local-first contract that
  turns workflow evidence into no-op, recommendation, router fixture,
  contract patch, or mechanical check outcomes.
- Added `workflow/skills/ambitious-project-loop.md`, an A-to-Z project
  lifecycle from intent, context, spec, decisions, slicing, implementation,
  dogfood, review, handoff, and retrospective learning.
- Updated `workflow/spec.md`, README, scaffold docs, Pi/Claude/Codex adapter
  references, and workflow docs smoke pins so the new contracts are discoverable
  without duplicating phase lists.
- Added event ledger types for self-improvement candidates and project slices.
- Updated Pi and Claude router logic plus fixtures/evals so self-improvement
  and ambitious project prompts route through `plan-implement`, while explicit
  review or explanation prompts stay read-only.

## Context
- `workflow/spec.md`: `PLAN.md` remains the only active execution artifact, and
  implementation still requires `Status: READY`.
- `workflow/skills/ship.md`: `/ship` remains explicit-only and carries branch
  push and PR creation consent; A-to-Z project wording alone does not imply it.
- `workflow/runtime-capabilities.json`: Pi subagents remain `blocked`, Codex
  subagents remain `unknown`, and goal-state claims stay runtime-scoped.
- `scripts/workflow-retrospect`: remains read-only; self-improvement contracts
  may use its output as evidence but not as an auto-patch source.

## Decisions
### Keep New Concepts On Existing Routes
- Context: Adding new route values would require broader adapter and command
  churn.
- Choice: Route self-improvement and ambitious project prompts to
  `plan-implement` or `implement` when an actual `READY PLAN.md` exists.
- Rejected options: create separate `self-improvement` and `project` route
  values, or ambiently route A-to-Z wording to `/ship`.
- Rationale: existing gates already cover plan/adversary/implementation/review,
  and `/ship` has explicit push/PR consent semantics.
- Consequences: prompts get stronger contracts without new write permissions.

### Preserve Review Intent Around Self-Improvement
- Context: `findings` is part of the review pattern and initially routed a
  self-improvement prompt to `review`.
- Choice: add `EXPLICIT_REVIEW_PATTERN` so recurring findings can route to
  self-improvement while explicit review/audit prompts stay `review`.
- Rejected options: weaken review routing globally, or change the test prompt to
  hide the conflict.
- Rationale: the real user wording can include "findings"; the router should
  handle that.
- Consequences: fixtures now cover both recurring-findings implementation and
  explicit review of the self-improvement loop.

### Keep Retrospect Safe
- Context: self-improvement can easily become unsafe auto-mutation.
- Choice: contracts state that retrospective output is candidate evidence only.
- Rejected options: auto-create router fixtures or patch workflow contracts
  directly from `workflow-retrospect`.
- Rationale: reviewed `PLAN.md` and focused validation are still required.
- Consequences: the helper remains diagnostic; implementation remains gated.

## Accepted Drift
- Original plan/spec: update `workflow/runtime-capabilities.json` only if needed.
- Implemented reality: no capability label changes were needed.
- Why accepted: the new contracts reuse the existing capability label rules and
  do not claim new runtime support.

- Original plan/spec: dynamic workflow artifact verification if a local artifact
  is created.
- Implemented reality: no `.workflow/<slug>` dynamic workflow artifact was
  created; only the required event ledger was recorded.
- Why accepted: fixtures and smoke tests provide the simulated lifecycle proof
  for this scoped workflow-contract change.

## Validation Evidence
- `bun test pi/extensions/__tests__/`
  - result: passed, 194 tests
- `bash tests/workflow-docs-smoke.sh`
  - result: passed
- `bash tests/workflow-contract-coverage-smoke.sh`
  - result: passed
- `bash tests/workflow-scaffold-smoke.sh`
  - result: passed
- `bash tests/workflow-event-smoke.sh`
  - result: passed
- `bash tests/workflow-retrospect-smoke.sh`
  - result: passed
- `bash tests/workflow-monitor-smoke.sh`
  - result: passed
- `bash tests/workflow-metrics-smoke.sh`
  - result: passed
- `bash tests/workflow-dossier-smoke.sh`
  - result: passed
- `bash tests/router-eval-smoke.sh`
  - result: passed
- `bash tests/claude-hooks-smoke.sh`
  - result: passed
- `bash tests/agent-scenarios-smoke.sh`
  - result: passed
- `git diff --check`
  - result: passed
- `scripts/workflow-event validate self-improvement-ambitious-project`
  - result: passed after archive with 26 events

## Follow-up State
- Remaining risks: live runtime behavior for Pi Task* and Codex/Claude subagent
  delegation remains bound to `workflow/runtime-capabilities.json` proof labels.
- Parking lot: richer project-slice reporting in `workflow-retrospect` if future
  real runs show repeated slice-level blockers.
- Superseded docs/specs: none.
- Next links:
  - `workflow/skills/self-improvement-loop.md`
  - `workflow/skills/ambitious-project-loop.md`
  - `workflow/events.md`
  - `pi/extensions/lib/workflow-router-runtime.ts`
  - `claude/hooks/workflow-router-lib.mjs`
