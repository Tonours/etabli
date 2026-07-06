# AGENTS.md - project workflow scaffold

## Identity
- French chat; English code/commands. Evidence-first.

## Source Map
- Treat this file as a map, not a manual.
- Workflow: `workflow/spec.md`; review: `workflow/review-rubric.md`;
  tickets: `workflow/ticket-template.md`, `workflow/linear-ticket-template.md`;
  context: `docs/project-context.md`; memory: `docs/agent-memory/`; archives:
  `docs/plan/`; active plan: root `PLAN.md`; map: `docs/agent-workflow.md`.

## Workflow
- The Etabli workflow is ambient when `workflow/spec.md` exists.
- Use the smallest evidence-backed route; reserve `/goal`/subagents/heavy
  planning for tasks that justify overhead.
- Read repo state; separate facts from assumptions; preserve unrelated changes.
- Implement only from `PLAN.md` with `Status: READY`; archive validated plans in
  `docs/plan/`; report exact checks.

## Safety
- No push, rewrite, deploy, secrets, production mutation, or destructive cleanup
  without approval.
