# AGENTS.md (global)

## Identity
- Language: French for communication, English for code.
- Be concise. No fluff, no filler.

## Philosophy
- YAGNI, KISS, DRY — in that order.
- Simple > clever. Obvious > elegant.
- No over-engineering. No premature abstractions.
- Three similar lines > one premature helper.
- Only build what's needed now.

## Code
- TypeScript strict, no `any`. ES modules only.
- Functions < 50 lines, files < 300 lines.
- Prefer composition over inheritance.
- Handle errors explicitly — never swallow.
- No console.log in production code.
- No deps without justification.

## Stack defaults
- Runtime: bun. Use node only if bun incompatible.
- Monorepos: pnpm + Turbo.
- Test: vitest (or bun test for simple projects).
- Lint/format: Biome. ESLint only if project already uses it.
- UI: React + Tailwind + Shadcn. No other component libs.

## Workflow
- TDD: test first, watch it fail, minimal code to pass.
- Use `/loop tests` for red-green-refactor cycles.
- Run single relevant test, not full suite.
- Run typecheck after changes.
- Verify before committing. Always.
- Use `/skill:review` before committing.
- Commit format: `feat|fix|refactor|test|docs|chore(scope): description`
- Atomic commits: one logical change per commit.

## Cross-tool convention files
- In any repo, check local convention files before changing code: `CLAUDE.md`, `.claude/commands/`, `.claude/settings.json`, `.cursor/rules/`, `.cursorrules`, `COPILOT.md`, `.github/copilot-instructions.md`.
- If a repo defines a reusable command/workflow in `.claude/commands/`, follow it when the task matches.
- Pi owns runtime behavior and extensions. Claude owns reusable command/docs surfaces. Keep the workflow aligned, not duplicated.
- Shared default flow: learn → plan → implement → review → handoff.
- In this repo, canonical workflow docs live in `workflow/spec.md`, `workflow/statuses.md`, `workflow/review-rubric.md`, and `workflow/handoff-template.md`.
- Profile docs live in `profiles/README.md` and `docs/profiles.md`.
- Memory contract lives in `memory/projects/README.md`.

## Delegation defaults
- Prefer a named reconnaissance/review role over generic delegation when possible.
- Use `scout` for codebase reconnaissance and `reviewer` for focused review work.
- Use `worker` for bounded implementation tasks that need direct code changes.
- Keep delegation read-only unless the task explicitly needs implementation.

## Agentic dev loop
- Default loop: `scout` → main session plan/refine → `worker` implement → `reviewer` check.
- `scout` and `reviewer` are read-only by default.
- `worker` may edit code, claim/get/append/update/close persistent `todo` items when relevant, and should stay bounded to a concrete task.

## Model usage
- Planning & analysis: prefer reasoning models (Kimi K2.5, GPT-5.3 xhigh)
- Implementation: prefer coding models (GPT-5.3 Codex, Kimi K2.5)
- Quick iterations: prefer fast models (GPT-5-mini, Haiku, Flash)

## Communication
- Be direct. No hedging, no "I think maybe we could...".
- Don't explain what you're about to do — just do it.
- Don't ask "should I proceed?" — proceed unless it's destructive.

## When stuck
- Try first, ask second. Don't ask permission for small decisions.
- For architectural choices: propose options, don't just pick one.
- If blocked after 2 attempts: stop and explain what failed.

## Prototyping
- Prototypes are disposable. Don't architect them like production.
- Speed > correctness for protos. Skip tests unless asked.
- When exploring: one file > three files.

## Don't
- Don't add features beyond what's asked.
- Don't refactor code you didn't change.
- Don't add comments, docstrings, or types to unchanged code.
- Don't create helpers for one-time operations.
- Don't design for hypothetical future requirements.

## Common mistakes to avoid
<!-- Updated when Pi makes mistakes — use /skill:learn pattern -->
