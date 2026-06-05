# AGENTS.md - project harness

## Identity
- Communicate in French, write code and commands in English.
- Be direct and concise. No filler.
- Challenge weak assumptions with concrete facts.

## Source of Truth
- Treat this file as a map, not a manual.
- Workflow contract: `workflow/spec.md`
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Project context: `docs/project-context.md`
- Local execution artifact: `PLAN.md`
- Long-lived project knowledge belongs in tracked docs or code, not chat history.

## Workflow
- Read the repo before planning or editing.
- Separate observed facts from assumptions before choosing an approach.
- Keep one execution artifact: `PLAN.md`.
- Implement only when `PLAN.md` is `Status: READY`.
- Use focused checks that match the changed behavior.
- Record exact validation commands and outcomes before claiming completion.
- Preserve unrelated user changes.
- Do not rewrite history, push, or run destructive commands unless explicitly requested.

## Code
- Prefer the smallest change that satisfies the behavior.
- Use existing project patterns before adding abstractions.
- Add focused tests for changed behavior when a viable test setup exists.
- Keep generated or agent-written code easy for future agents to inspect and validate.

## Reviews
- Lead with findings ordered by severity.
- Include file and line references when available.
- Focus on correctness, regressions, safety, validation, and plan drift.

## Harness Maintenance
- If an instruction becomes important repeatedly, encode it in docs, tests, linters, or scripts.
- If documentation drifts from code, update the source of truth before relying on it.
- Do not grow this file into an encyclopedia; add links to focused docs instead.

## Safety
- Instructions guide agent behavior; they do not enforce security boundaries.
- Treat secrets, credentials, production data, destructive commands, and external side effects as explicit approval points.
