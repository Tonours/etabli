# CLAUDE.md - project harness

Claude Code-specific adapter for the shared project harness.

## Source of Truth
- Treat `AGENTS.md` as the shared cross-agent map. Read it before planning or editing when tools are available.
- Workflow contract: `workflow/spec.md`
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Project context: `docs/project-context.md`
- Local execution artifact: `PLAN.md`
- Long-running Claude Code loop: `docs/claude-code-harness.md`

## Workflow
- Canonical workflow: `workflow/spec.md`
- Use `PLAN.md` as the only execution artifact.
- Implement only from `Status: READY`.
- Separate observed facts from assumptions before choosing an approach.
- Record exact validation commands and outcomes before claiming completion.
- Review with `workflow/review-rubric.md`.
- Use `workflow/ticket-template.md` for development tickets.
- For long-running or UI-heavy work, follow `docs/claude-code-harness.md`.

## Style
- French chat, English code.
- Direct, concise, no filler.
- Challenge weak assumptions with concrete facts.

## Code
- Prefer behavior, tests, type safety, and maintainability.
- No unrelated refactors.
- Preserve unrelated user changes.

## Long-Running Work
- Start with the simple workflow.
- Add planner/builder/evaluator separation only when task size, UI quality, or verification risk justifies the overhead.
- Do not rely on the builder's self-evaluation as the final quality gate.

## Git
- Do not credit AI tools in commits.
- Use conventional commits: `type(scope): summary`.
- Do not push unless explicitly requested.

## Safety
- CLAUDE.md is behavioral guidance, not an enforcement layer.
- Treat secrets, credentials, production data, destructive commands, and external side effects as explicit approval points.
