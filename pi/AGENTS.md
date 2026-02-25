# AGENTS.md

## Code style
- TypeScript strict, no `any`
- ES modules only (import/export)
- Prefer composition over inheritance
- Functions < 50 lines, files < 300 lines
- Destructure imports when possible

## Architecture
- src/api/ — Route handlers
- src/services/ — Business logic
- src/lib/ — Shared utilities
- src/types/ — TypeScript types
- Tests next to source: foo.ts → foo.test.ts

## Workflow
- TDD: write tests first, then implementation
- Use `/loop tests` for red-green-refactor cycles
- Run typecheck after changes
- Run single relevant test, not full suite
- Atomic commits: one logical change per commit
- Always verify before committing
- Use `/skill:review` before committing
- Commit format: feat|fix|refactor|test|docs|chore(scope): description

## Model usage
- Planning & analysis: prefer reasoning models (Kimi K2.5, o3)
- Implementation: prefer coding models (GPT-5.3 Codex, Kimi K2.5)
- Quick iterations: prefer fast models (GPT-5-mini, Haiku, Flash)

## Non-negotiables
- Never add deps without justification
- Always verify changes work
- Never modify deployed migrations
- Handle errors explicitly, never swallow
- No console.log in production code

## Common mistakes to avoid
<!-- Updated when Pi makes mistakes — use /skill:learn pattern -->
