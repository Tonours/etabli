# Agent Workflow

This project includes the Etabli agent workflow.

## Sources
- Entry points: `AGENTS.md`, `CLAUDE.md`
- Canonical loop: `workflow/spec.md`
- Shared contracts: `workflow/skills/`
- Orchestration: `workflow/skills/orchestration.md`
- Self-improvement: `workflow/skills/self-improvement-loop.md`
- Ambitious projects: `workflow/skills/ambitious-project-loop.md`
- Reviews/tickets: `workflow/review-rubric.md`,
  `workflow/ticket-template.md`, `workflow/linear-ticket-template.md`
- Memory/archive: `docs/agent-memory/README.md`,
  `workflow/plan-archive.md`, `docs/plan/README.md`
- Project facts: `docs/project-context.md`

## Activation
`workflow/spec.md` activates the smallest applicable route. Explicit `/goal`,
`subagents`, or `plan-loop` requests heavier orchestration. READY remains the
implementation gate; push, PR, deploy, release, and external writes still need
consent.

Adapters: Pi Coding Agent reads `AGENTS.md`; Claude Code reads `CLAUDE.md`.

## Maintenance
Keep entrypoints short; put shared behavior in `workflow/skills/` and enforce
hard boundaries with hooks, tests, CI, or sandbox settings.
