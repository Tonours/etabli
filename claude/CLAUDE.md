# CLAUDE.md - etabli

Claude Code adapter for this repo. Shared identity, style, cognition, code,
review, ticket, anti-sycophancy, contrarian, and git rules live in
`pi/AGENTS.md` and apply here verbatim; read that file first. The rules below
are only Claude-specific additions or overrides.

## Source of Truth
- Root repo map: `AGENTS.md`
- Shared Pi guidance: `pi/AGENTS.md`
- Workflow contract: `workflow/spec.md`
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Default plan: `PLAN_TEMPLATE.md`
- Full plan for risky work: `PLAN_TEMPLATE_FULL.md`
- Local execution artifact: `PLAN.md`

## Workflow
- Follow `workflow/spec.md`; Claude hooks inject the selected route.
- Use `PLAN.md` as the only execution artifact and implement only from
  `Status: READY`.
- Use `/verify-workflow` for workflow evidence checks. Do not shadow Claude
  Code's native `/verify`.
- Use `/goal` for long-running "keep going until done" work with a measurable
  condition and explicit validation evidence.
- Use `workflow/skills/orchestration.md` for Pi/Claude orchestration parity:
  Claude uses `/goal`, commands, and hooks; Task* state is Pi-only unless the
  active runtime exposes an equivalent primitive.
- Test naming (esp. agent-nodejs): `describe('when ...')` for context blocks,
  `it('should ...')` for behavior. Top-level `describe` may name the unit;
  nested describes use `when`.
- Do not create `REVIEW.md`.
- After implementing a `READY` plan, archive the distilled result in
  `docs/plan/YYYYMMDD-short-slug.md`; delete only the current workspace root
  `PLAN.md` after validation and archive success.

## Claude Runtime
- Runtime: Node.js (TypeScript). Tests: Vitest or Jest as configured. Lint:
  ESLint/Biome when available.
- Claude guidance is behavioral guidance, not a security boundary.

## Subagent Model
- Small task (scout, code reading, locate, mechanical edit): use `sonnet`.
- Otherwise (planning, implementation, complex reasoning, review): use `opus`.

## Safety
- Treat secrets, credentials, production data, destructive commands, and
  external side effects as explicit approval points.
- Checkpoint taxonomy and enforcement map: `workflow/spec.md` -> Human
  checkpoints.
