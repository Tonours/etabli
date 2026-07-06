# CLAUDE.md - project workflow scaffold

Claude Code-specific adapter for the shared project workflow scaffold.

## Sources
- Shared map: `AGENTS.md`; workflow: `workflow/spec.md`; review:
  `workflow/review-rubric.md`; tickets: `workflow/ticket-template.md`,
  `workflow/linear-ticket-template.md`; context: `docs/project-context.md`;
  memory: `docs/agent-memory/`; archives: `docs/plan/`; active plan:
  `PLAN.md`; long loop: `docs/claude-code-workflow.md`.

## Workflow
- The Etabli workflow is ambient when `workflow/spec.md` exists.
- Ordinary work uses ordinary commands; `/goal` is for measurable long tasks.
- Implement only from `PLAN.md` with `Status: READY`; after validation archive
  to `docs/plan/` and delete only root `PLAN.md`.
- Review with `workflow/review-rubric.md`; tickets use
  `workflow/ticket-template.md`.

## Safety
- French chat, English code. Preserve unrelated changes. No push, rewrite,
  deploy, secrets, or destructive cleanup without approval.
