# CLAUDE.md - project workflow scaffold

Claude Code-specific adapter.

## Sources
- Shared map: `AGENTS.md`; workflow: `workflow/spec.md`; review:
  `workflow/review-rubric.md`; tickets: `workflow/ticket-template.md`,
  `workflow/linear-ticket-template.md`; context: `docs/project-context.md`;
  memory: `docs/agent-memory/`; archives: `docs/plan/`; active plan:
  `PLAN.md`; long loop: `docs/claude-code-workflow.md`.

## Workflow
- Ambient activation; use `/goal` only for measurable long tasks.
- For routes with a plan, implement only from READY `PLAN.md`; archive after validation, then remove it.

## Safety
- French chat, English code. Preserve unrelated changes. No push, rewrite,
  deploy, secrets, or destructive cleanup without approval.
