# AGENTS.md — etabli (dotfiles repo)

## Architecture
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
- ~/.pi/agent/AGENTS.md → pi/AGENTS.md (global coding preferences)
- ~/.pi/settings.json → pi/settings.json
- ~/.pi/themes/ → pi/themes/
- ~/.pi/damage-control-rules.json → pi/damage-control-rules.json
- pi/extensions/node_modules/ → ~/.pi/npm/node_modules/ (for createRequire resolution)
- Do NOT create ~/.pi/extensions/ — it causes double-loading conflicts

## Testing
- Nightshift tests: `bun test pi/extensions/lib/nightshift/__tests__/`
- Ship tests: `bun test pi/extensions/__tests__/`
- Agentic scripts: `python -m pytest tests/agentic/`
