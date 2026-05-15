# CLAUDE.md — etabli

Claude-specific deltas for this repo.

## Style

- FR chat, EN code.
- Direct, concise, no filler.
- Challenge weak assumptions with concrete facts.

## Workflow

- Follow `workflow/spec.md`.
- Use `PLAN.md` as the only execution artifact.
- Implement only from `Status: READY`.
- Do not create `REVIEW.md`.
- Review with `workflow/review-rubric.md`.

## Code

- YAGNI, KISS, DRY, in that order.
- TypeScript strict, no `any`, ES modules.
- Runtime: bun. Tests: vitest/bun as configured.
- No refactor outside requested scope.

## Commit

- No Claude credit.
- Conventional commit: `type(scope): summary`.
