# CLAUDE.md - project workflow scaffold

Claude Code-specific adapter for the shared project workflow scaffold.

## Source of Truth
- Treat `AGENTS.md` as the shared cross-agent map. Read it before planning or editing when tools are available.
- Workflow contract: `workflow/spec.md`
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Linear ticket template: `workflow/linear-ticket-template.md`
- Project context: `docs/project-context.md`
- Durable lessons from past runs: `docs/agent-memory/`
- Implemented plan archives: `docs/plan/`
- Local execution artifact: `PLAN.md`
- Long-running Claude Code loop: `docs/claude-code-workflow.md`

## Workflow
- Canonical workflow: `workflow/spec.md`
- Use `PLAN.md` as the only execution artifact.
- Implement only from `Status: READY`.
- Archive implemented and validated plans in `docs/plan/`; never archive drafts, challenged plans, or abandoned ready plans.
- Read `docs/agent-memory/` before non-trivial work; write a lesson when a correction or confirmed approach will matter again.
- Separate observed facts from assumptions before choosing an approach.
- Before reporting progress or completion, audit each claim against a tool result from this session. Record exact validation commands and outcomes before claiming completion.
- When the user explicitly asks for assessment, review, diagnosis, or thinks out loud without asking for a fix, report findings and stop. Otherwise, fix the problem once you have enough evidence.
- When you have enough information to act, act. Do not re-derive established facts or re-litigate decisions the user already made.
- Pause for the user only for destructive/irreversible actions, real scope changes, or input only they can provide. Otherwise proceed and end the turn on completed work, not on a promise.
- Review with `workflow/review-rubric.md`.
- Use `workflow/ticket-template.md` for development tickets.
- For long-running or UI-heavy work, follow `docs/claude-code-workflow.md`.

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
- Final summaries of long runs are written for a reader who did not watch the run: outcome first, complete sentences, no working shorthand, no arrow chains.

## Git
- Do not credit AI tools in commits.
- Use conventional commits: `type(scope): summary`.
- Do not push unless explicitly requested.

## Safety
- CLAUDE.md is behavioral guidance, not an enforcement layer.
- Treat secrets, credentials, production data, destructive commands, and external side effects as explicit approval points.
