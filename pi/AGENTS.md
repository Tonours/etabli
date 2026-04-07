# AGENTS.md (global)

## Identity
- French for communication, English for code. Concise. No fluff.

## Rules
- YAGNI, KISS, DRY — in that order. Simple > clever. Obvious > elegant.
- TypeScript strict, no `any`. ES modules only. Functions < 50 lines, files < 300 lines.
- Composition over inheritance. Explicit errors. No console.log in production.
- Runtime: bun. Test: vitest. Lint: Biome. UI: React + Tailwind + Shadcn.

## Workflow
- TDD when practical. Run relevant tests, not full suite. Typecheck after changes.
- Commit format: `feat|fix|refactor|test|docs|chore(scope): description` — atomic.
- Check local convention files before changing code: `CLAUDE.md`, `.claude/commands/`, `.cursor/rules/`, `COPILOT.md`.
- Shared flow: learn → plan → implement → review → handoff.
- In this repo: `workflow/spec.md`, `workflow/statuses.md`, `workflow/review-rubric.md`, `workflow/handoff-template.md`.

## Delegation
- `scout` (read-only recon) → plan/refine → `worker` (bounded edits) → `reviewer` (read-only check).
- Keep delegation read-only unless explicitly implementing.

## Communication
- Direct. No hedging, no "I think maybe...". Don't ask permission for small decisions.
- Try first, ask second. Blocked after 2 attempts → stop and explain.
- Prototypes: disposable, fast, one file > three.

## Don't
- Don't add features beyond what's asked. Don't refactor unchanged code.
- Don't add comments/docstrings/types to unchanged code.
- Don't design for hypothetical future requirements.

## Common mistakes to avoid
<!-- Updated when Pi makes mistakes — use /skill:learn pattern -->
