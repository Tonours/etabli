# Agent Workflow

This project includes the Etabli agent workflow.

## Source Map
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

## Activation is ambient
`workflow/spec.md` activates the workflow. Normal prompts use the smallest
route; explicit `/goal`, `workflow`, `subagents`, or `plan-loop` means heavier
orchestration.

Self-improvement and ambitious project prompts still use the normal READY gate.
They add stronger evidence and slicing contracts; they do not imply push, PR,
deploy, release, or external write-back consent.
Self-improvement candidates keep weakness patterns, bounded proposals,
held-in/held-out validation, and rejected candidates in the local ledger.

## Pi Coding Agent
Pi uses `AGENTS.md` as the project map.

## Claude Code
Claude uses `CLAUDE.md` plus `docs/claude-code-workflow.md`.

## Maintenance
Keep entrypoints short; move project facts to docs, shared behavior to
`workflow/skills/`, and hard boundaries to hooks/tests/CI/sandbox settings.
