# AGENTS.md

## Code style
- TypeScript strict, no `any`
- ES modules only (import/export)
- Prefer composition over inheritance
- Functions < 50 lines, files < 300 lines
- Destructure imports when possible

## Architecture (dotfiles repo)
- pi/extensions/                       — Pi extensions (TypeScript, auto-loaded from ~/.pi/agent/extensions/)
- pi/extensions/lib/                   — Shared utilities between extensions
- pi/extensions/lib/nightshift/        — Nightshift modules (see lib/nightshift/ for full list)
- pi/extensions/lib/nightshift/__tests__/ — Nightshift unit tests
- pi/extensions/lib/ship-utils.ts      — Ship shared utilities (session key, history, prune)
- pi/extensions/__tests__/             — Extension-level tests (ship)
- pi/damage-control-rules.json        — Safety rules for damage-control extension
- pi/agent/settings.json              — Pi agent settings (packages, model, theme)
- pi/settings.json                    — Pi root settings (theme, editor)
- pi/models.json                      — Custom model definitions
- pi/skills/                           — Pi skills (Markdown SKILL.md)
- pi/themes/                           — Custom themes (JSON)
- scripts/                             — Install & dev scripts (Bash)
- nvim/                                — Neovim config (Lua, LazyVim)
- ghostty/                             — Ghostty terminal config
- yabai/ skhd/ sketchybar/ borders/    — Tiling WM configs (macOS)

## Extension conventions
- One extension per file in pi/extensions/
- Shared helpers go in pi/extensions/lib/
- Extensions are auto-loaded from ~/.pi/agent/extensions/ (symlinked to pi/extensions/)
- External packages (npm/git) are declared in pi/agent/settings.json packages
- Security layers: damage-control (pre-execution gate) → filter-output (post-execution redaction)
- Safety rules in pi/damage-control-rules.json (symlinked to ~/.pi/)

## Symlink layout (~/.pi/)
- ~/.pi/agent/extensions/ → pi/extensions/ (auto-loaded by Pi)
- ~/.pi/agent/settings.json → pi/agent/settings.json
- ~/.pi/agent/AGENTS.md → pi/AGENTS.md
- ~/.pi/settings.json → pi/settings.json
- ~/.pi/themes/ → pi/themes/
- ~/.pi/damage-control-rules.json → pi/damage-control-rules.json
- pi/extensions/node_modules/ → ~/.pi/npm/node_modules/ (for createRequire resolution)
- Do NOT create ~/.pi/extensions/ — it causes double-loading conflicts

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
