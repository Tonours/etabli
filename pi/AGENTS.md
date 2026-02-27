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

## Ship pipeline
1. `/ship start --task "..."` — start tracked run
2. `/skill:plan` — create implementation plan
3. `/skill:plan-review` — stress-test the plan
4. implement — write code
5. `/skill:verify` — type-check, test, lint, build
6. `/skill:review` — code review
7. `/ship mark --result go|block` — record decision

## Model usage
- Planning & analysis: prefer reasoning models (Kimi K2.5, o3)
- Implementation: prefer coding models (GPT-5.3 Codex, Kimi K2.5)
- Quick iterations: prefer fast models (GPT-5-mini, Haiku, Flash)

## Plan mode
- Plans MUST be extremely concise. Sacrifice grammar for brevity.
- End every plan with unresolved questions, if any.

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
