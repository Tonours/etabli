# AGENTS.md

## Code style
- TypeScript strict, no `any`
- ES modules only (import/export)
- Prefer composition over inheritance
- Functions < 50 lines, files < 300 lines
- Destructure imports when possible

## Architecture (dotfiles repo)
- pi/extensions/     — Pi extensions (TypeScript, auto-loaded via settings.json)
- pi/extensions/lib/ — Shared utilities between extensions
- pi/skills/         — Pi skills (Markdown SKILL.md)
- pi/themes/         — Custom themes (JSON)
- pi/agent/          — Agent-level settings
- scripts/           — Install & dev scripts (Bash)
- nvim/              — Neovim config (Lua, LazyVim)
- ghostty/           — Ghostty terminal config
- yabai/ skhd/ sketchybar/ borders/ — Tiling WM configs (macOS)

## Extension conventions
- One extension per file in pi/extensions/
- Shared helpers go in pi/extensions/lib/
- Auto-loaded extensions registered in pi/agent/settings.json packages
- Opt-in extensions loaded via `pi -e extensions/<name>.ts`
- Security layers: damage-control (pre-execution gate) → filter-output (post-execution redaction)

## Workflow
- TDD: write tests first, then implementation
- Use `/loop tests` for red-green-refactor cycles
- Run typecheck after changes
- Run single relevant test, not full suite
- Atomic commits: one logical change per commit
- Always verify before committing
- Use `/skill:review` before committing
- Commit format: feat|fix|refactor|test|docs|chore(scope): description

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

## Non-negotiables
- Never add deps without justification
- Always verify changes work
- Never modify deployed migrations
- Handle errors explicitly, never swallow
- No console.log in production code

## Common mistakes to avoid
<!-- Updated when Pi makes mistakes — use /skill:learn pattern -->
