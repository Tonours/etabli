# CLAUDE.md - etabli

Claude Code adapter. Shared identity, style, cognition, code, review, ticket,
anti-sycophancy, contrarian, and git rules live in `pi/AGENTS.md`; read it.

## Sources
- Repo: `AGENTS.md`; shared rules: `pi/AGENTS.md`; workflow:
  `workflow/spec.md`; review: `workflow/review-rubric.md`; tickets:
  `workflow/ticket-template.md`; plans: `PLAN_TEMPLATE*.md`, root `PLAN.md`.
- Vault: `~/work/obvault` (`~/work/obvault/CLAUDE.md`).

## Claude Workflow
- Follow `workflow/spec.md`; Claude hooks inject the selected route.
- `/goal` only for measurable long loops with validation evidence and a cap.
- Use root `PLAN.md` only; implement only from `Status: READY`.
- After validation, archive to `docs/plan/YYYYMMDD-short-slug.md`, then delete root `PLAN.md`.
- Answers/handoffs follow `workflow/answer-quality.md`; durable artifacts can
  use `scripts/answer-quality-check`.
- Final answers apply the live gate in `workflow/answer-quality.md`: answer the
  newest request, name unverified gaps, and do not promise a perfect score.
- Use `/verify-workflow` for workflow evidence; do not shadow native `/verify`.
- Orchestration parity: `workflow/skills/orchestration.md`; Pi Task* state is
  Pi-only unless equivalent runtime capability is exposed.

## Safety
- Runtime: Node.js/TypeScript, local tests. Secrets, production, destructive
  actions, deploys, billing, and external writes need approval.
