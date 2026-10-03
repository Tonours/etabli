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
to routes with a plan; push, PR, deploy, release, and external writes still need
consent.

Adapters: Pi Coding Agent reads `AGENTS.md`; Claude Code reads `CLAUDE.md`.

## Verification
New plan templates use `Required: auto`. Classify every AC as product, process
or judgment. Product criteria require actual action/result observations and
persistence when declared. Follow `workflow/product-verification.md`: discover
existing tests, prepare missing proof, adapt the versioned recipe, run the shared
collector, then recheck before closing. A missing prerequisite stays blocked.
The deterministic baseline needs no model key; select an optional engine
explicitly and configure only its required environment names locally.

## Maintenance
Keep entrypoints short; put shared behavior in `workflow/skills/` and enforce
hard boundaries with hooks, tests, CI, or sandbox settings.
