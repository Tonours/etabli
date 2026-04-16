# AGENTS.md — etabli (dotfiles repo)

## Architecture
- pi/extensions/                       — Pi extensions (TypeScript, auto-loaded from ~/.pi/agent/extensions/)
- pi/extensions/lib/                   — Shared utilities between extensions
- pi/extensions/__tests__/             — Extension-level tests
- pi/damage-control-rules.json        — Safety rules for damage-control extension
- pi/agent/settings.json              — Pi agent settings (packages, model, theme)
- pi/settings.json                    — Pi root settings (theme, editor)
- pi/models.json                      — Custom model definitions
- pi/skills/                           — Pi skills (Markdown SKILL.md)
- pi/themes/                           — Custom themes (JSON)
- scripts/                             — Install & dev scripts (Bash)
- vscode/                              — VS Code user config (settings, keybindings, extensions)
- iterm2/                              — iTerm2 dynamic profile
- yabai/ skhd/ sketchybar/             — Tiling WM configs (macOS)

## Extension conventions
- One extension per file in pi/extensions/
- Shared helpers go in pi/extensions/lib/
- Extensions are auto-loaded from ~/.pi/agent/extensions/ (symlinked to pi/extensions/)
- External packages (npm/git) are declared in pi/agent/settings.json packages
- Security layers: damage-control (pre-execution gate) → filter-output (post-execution redaction)
- Safety rules in pi/damage-control-rules.json (symlinked to ~/.pi/)

## Symlink layout (~/.pi/)
- ~/.pi/agent/extensions/ → pi/extensions/ (auto-loaded by Pi)
- ~/.pi/agent/settings.json stays local (bootstrapped from pi/agent/settings.json on install)
- ~/.pi/agent/models.json → pi/models.json
- ~/.pi/agent/AGENTS.md → pi/AGENTS.md (global coding preferences)
- ~/.pi/settings.json → pi/settings.json
- ~/.pi/themes/ → pi/themes/
- ~/.pi/damage-control-rules.json → pi/damage-control-rules.json
- pi/extensions/node_modules/ → ~/.pi/npm/node_modules/ (for createRequire resolution)
- Do NOT create ~/.pi/extensions/ — it causes double-loading conflicts

## Testing
- Extension tests: `bun test pi/extensions/__tests__/`

## Anti-sycophancy
- Never flatter, agree by default, or mirror my wording to seem aligned.
- Never say "great idea", "absolutely", "you're right" unless independently verified.
- If I'm wrong, say so directly. If unsure, say so. If in agreement, don't perform agreement — just act.
- No filler praise. No "Sure!" or "Of course!" before answering. Start with the answer.
- If you catch yourself agreeing without adding value, stop and reassess.

## Contrarian Stance
- When I propose a strategy, architecture, or design decision: challenge it. Point out blind spots, weak assumptions, and failure modes before agreeing.
- Do not validate by default. Push back with concrete counter-arguments.
- Only agree when you have no substantive objection left.
