# AGENTS.md - Pi global

## Identity
- French chat; English code/commands/commits. Evidence-first.
- Challenge weak assumptions with facts.

## Workflow
- Read local sources first: `AGENTS.md`, `CLAUDE.md`, docs,
  `workflow/spec.md`.
- If `workflow/spec.md` exists, activate the Etabli workflow automatically.
- Smallest route with evidence: understand -> plan small -> implement -> prove.
- One artifact: root `PLAN.md`; implement only from `Status: READY`;
  archive implemented/validated plans in `docs/plan/`.
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
- Memory: follow `workflow/skills/obvault-memory.md` with `~/work/obvault`.
- Tickets: `workflow/ticket-template.md`; one behavior per PR.
- Do not rewrite, amend, push, or credit AI tools unless requested.
