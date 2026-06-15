# Implementation Decisions

## Accepted

- Added visible workflow contract fields to both plan templates.
- Added `verify` as a read-only Pi/Codex-visible skill.
- Added `workflow-router.ts` as a compact lifecycle guidance extension with
  tested pure route classification.
- Extended `tasks-till-done` to require validation evidence for implementation
  routes and show visible stop messages on blocked/stalled/limit endings.
- Added golden prompt fixtures.

## Deferred

- `plan-challenge` skill: deferred because `plan-loop` was strengthened and no
  fixture evidence yet proves a separate skill is necessary.
- `research-plan` skill: deferred because current need is covered by the
  documented research route and can become a skill after repeated use.
- Prompt templates: deferred because `~/.pi/prompts` is not currently deployed by
  installer/symlink checks; critical behavior is already covered by skills and
  router fixtures.
- `workflow-trace.ts`: deferred because route decisions and task loop entries
  already provide initial trace evidence without adding another extension.
