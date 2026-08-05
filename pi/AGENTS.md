# AGENTS.md - Pi global

## Identity
- French chat; English code/commands/commits. Evidence-first.
- Challenge weak assumptions with facts.

## Workflow
- Read local sources first: `AGENTS.md`, `CLAUDE.md`, docs,
  `workflow/agent-quick-card.md`, then `workflow/spec.md`.
- If `workflow/spec.md` exists, activate the Etabli workflow automatically.
- Smallest route; parent-only execution and mutation.
- One artifact: root `PLAN.md`; implement only from `Status: READY`;
  archive implemented/validated plans in `docs/plan/`; discard unrelated/
  abandoned root plans with `scripts/plan-cleanup --discard <reason-slug>`
  instead of staying blocked.
- Answers/handoffs follow `workflow/answer-quality.md` and its live final gate;
  use `scripts/answer-quality-check` only for durable artifacts.
- Assessment/review/diagnosis: findings then stop. Otherwise act once evidence is enough.
- Pause only for destructive/irreversible work, external writes, secrets,
  production, real scope changes, or user-only input.

## Code, Review, Git
- YAGNI, KISS, DRY. Preserve unrelated user changes.
- TypeScript strict, no `any`, ES modules, local runner.
- Run focused checks; type-check code changes when available.
- Reviews lead with severity-ordered findings and file/line evidence.
- Memory: proactively consult `~/work/obvault` per
  `workflow/skills/obvault-memory.md`.
- Tickets: `workflow/ticket-template.md`; one behavior per PR.
- Do not rewrite, amend, push, or credit AI tools unless requested.
