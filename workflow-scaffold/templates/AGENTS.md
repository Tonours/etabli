# AGENTS.md - project workflow scaffold

## Identity
- French chat; English code/commands. Evidence-first.

## Sources
- Workflow: `workflow/spec.md`; review: `workflow/review-rubric.md`;
  tickets: `workflow/ticket-template.md`, `workflow/linear-ticket-template.md`;
  context: `docs/project-context.md`; memory: `docs/agent-memory/`; archives:
  `docs/plan/`; active plan: root `PLAN.md`; map: `docs/agent-workflow.md`.

## Workflow
- Ambient activation; use the smallest evidence-backed route.
- Requests to inspect, examine, or look at uncommitted changes, a branch
  diff, or a commit are reviews: route through `workflow/skills/review.md`
  — dispatch an isolated Logic hunter (same-session self-review of Logic is
  forbidden), tables, Verdict line; never free-form commentary.
- Implement only from READY `PLAN.md`; archive validated plans in `docs/plan/`.
- Preserve unrelated changes and report exact checks.
- Instruction files stay maps, not manuals.

## Safety
- No push, rewrite, deploy, secrets, production mutation, or destructive cleanup
  without approval.
