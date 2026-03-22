# Neovim

Focused daily-driver config.

Good fit: TS/JS, React, Ember, Tailwind, CSS/SCSS, JSON/YAML, PHP.

Quick ref: `nvim/CHEATSHEET.md`

## Core flow

- Files: `<leader><space>`
- Grep: `<leader>/`
- Buffers: `<leader>.`
- Explorer: `<leader>ft`, `<leader>fe`
- Projects: `<leader>pp`
- Worktrees: `<leader>pw`
- Project info: `<leader>pi` or `:ProjectInfo`

Long-form aliases stay available:
- `<leader>ff`, `<leader>fg`, `<leader>fb`

## Project workflow

- Re-root to current buffer: `<leader>pr`
- Save project session: `<leader>ps`
- Load project session: `<leader>pl`
- Recent files in current project: `<leader>fp`

Statusline:
- `󰉋 name` = project
- ` branch` = worktree
- `•` = session exists
- `+` = session exists, context changed since last save

## Code workflow

- Symbols: `<leader>ss`, `<leader>sS`
- Diagnostics: `<leader>dd`, `<leader>dD`, `<leader>dl`, `[d`, `]d`
- Format: `<leader>cf`
- Implementation: `gI` or `<leader>ci` (buffer-local, LSP)
- Rename: `<leader>rn` (buffer-local, LSP)
- Code action: `<leader>ca` (buffer-local, LSP)
- Multi-cursor: `<C-n>` or `<leader>mn` next occurrence, `<leader>mj` / `<leader>mk` add vertical cursors

## Window policy

- Single-pane by default
- Splits only on purpose: `<leader>wv`, `<leader>wh`
- Buffers are primary; explorer opens files in tabs
- Explorer is visible support, not the main navigation model

## Notes

- Use `cw` to create/open worktrees.
- Use Neovim to switch between tracked projects/worktrees.
- `which-key` is enabled in a minimal mode for leader-map recall.
