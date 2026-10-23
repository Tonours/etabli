# Agent Workflow

This project includes the Etabli agent workflow.

## Sources
- Entry points: `AGENTS.md`, `CLAUDE.md`
- Canonical loop: `workflow/spec.md`
- Shared contracts: `workflow/skills/`
- Orchestration: `workflow/skills/orchestration.md`
- Reviews/tickets: `workflow/review-rubric.md`,
  `workflow/ticket-template.md`, `workflow/linear-ticket-template.md`
- Memory/archive: `docs/agent-memory/README.md`,
  `workflow/plan-archive.md`, `docs/plan/README.md`
- Project facts: `docs/project-context.md`

## Activation
`workflow/spec.md` activates the smallest applicable route. Explicit `/goal`,
`subagents`, or `plan-loop` requests heavier orchestration. The READY gate applies
to routes with a plan; nothing else pauses except user-only input (a
credential value, a real scope decision).

Adapters: Pi Coding Agent reads `AGENTS.md`; Claude Code reads `CLAUDE.md`.

## Verification
Classify every AC as product, process or judgment. Product criteria require
actual action/result observations from the affected flow, through existing
tests or a direct run. A missing prerequisite stays blocked.

## Maintenance
Keep entrypoints short; put shared behavior in `workflow/skills/` and enforce
hard boundaries with hooks, tests, CI, or sandbox settings.
