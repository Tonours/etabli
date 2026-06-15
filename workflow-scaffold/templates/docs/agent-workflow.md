# Agent Workflow

This project includes the Etabli agent workflow.

## Installed Surface

- `AGENTS.md` maps agent behavior and repo navigation.
- `CLAUDE.md` adapts the same workflow for Claude Code.
- `workflow/spec.md` defines the canonical loop.
- `workflow/review-rubric.md` defines review priorities.
- `workflow/ticket-template.md` defines development ticket format.
- `workflow/linear-ticket-template.md` adapts tickets to Linear fields.
- `workflow/memory.md` defines how durable agent lessons are recorded.
- `workflow/plan-archive.md` defines implemented plan archive records.
- `docs/agent-memory/README.md` is the default memory directory index.
- `docs/plan/README.md` is the default implemented-plan archive index.
- `docs/project-context.md` stores durable project-specific facts.
- `PLAN_TEMPLATE.md` and `PLAN_TEMPLATE_FULL.md` define execution plans.
- `docs/claude-code-workflow.md` defines the Claude Code long-running work loop.

## Operating Model

The workflow scaffold favors short entry-point instructions plus tracked, focused source-of-truth files. Agents should discover project facts from the repository, not from hidden chat context.

## Project-Specific Context

Add durable project knowledge under `docs/` or another tracked documentation directory:

- setup and validation commands
- architecture maps
- product decisions
- domain constraints
- known debt and recurring risks

Start with `docs/project-context.md`. Expand only when repeated agent mistakes show that a dedicated doc would pay for itself.

Keep `AGENTS.md` short. Link from it to focused docs when new context becomes stable.

## Claude Code

Use `CLAUDE.md` as the thin adapter. It repeats the minimum source-of-truth map because Claude Code reliably auto-loads `CLAUDE.md`, while `AGENTS.md` may require tool access in some modes. Keep Claude-specific long-running guidance in `docs/claude-code-workflow.md`.

## Pi Coding Agent

Use `AGENTS.md` as the Pi-facing entry point. Keep Pi-specific runtime configuration and personal skills outside the project unless the project owns them. The portable project workflow scaffold should depend on tracked docs, plans, tests, and commands that any agent can inspect.

## Safety

Instruction files shape behavior but do not enforce hard permissions. Use tool settings, sandboxing, hooks, CI policy, or review gates for actions that must be blocked mechanically.

## Existing Projects

When deploying into an existing project, do not overwrite local `AGENTS.md` or `CLAUDE.md` without reviewing the diff. Merge existing repository rules into the workflow map, then keep project-specific facts in tracked docs.
