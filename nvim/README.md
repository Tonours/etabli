# Neovim

Code-first minimal IDE config for Etabli project types.

Good fit: TS/JS, React, Ember, Tailwind, CSS/SCSS, JSON/YAML, Markdown, PHP, Lua/shell.

Quick ref: `nvim/CHEATSHEET.md`

## Core flow

- Files: `<leader><space>` or `Cmd/Ctrl+P`
- Command palette: `Cmd/Ctrl+Shift+P` or `:CommandPalette`
- Grep: `<leader>/`
- Find & replace: `<leader>fr`
- Buffers: `<leader>.`
- Projects: `<leader>pp`
- Project info: `<leader>pi` or `:ProjectInfo`
- Sidebar: `neo-tree` on the right with file icons; `<leader>ft` focuses it, `<leader>fe` reveals the current file
- Tabs: `bufferline` shows open buffers across the top
- Shortcut help: press `<leader>` and wait briefly for `which-key`

## Code workflow

- Symbols: `<leader>ss`, `<leader>sS`
- Diagnostics: `<leader>dd`, `<leader>dD`, `<leader>dl`, `[d`, `]d`
- Format: `<leader>cf`
- Implementation: `gI` or `<leader>ci`
- Rename: `<leader>rn`
- Code action: `<leader>ca`
- Git hunks: `[h`, `]h` (gitsigns; in-buffer only)
- Copilot native: `:LspCopilotSignIn` from a project buffer, `Tab` or `<A-l>` accept inline suggestion, `<A-]>` / `<A-[>` cycle suggestions
- Copilot controls: `:CopilotStatus`, `:CopilotDisable`, `:CopilotEnable`, `:CopilotToggle`
- Setup doctor: `:EtabliDoctor`

## Project workflow

- Re-root to current buffer: `<leader>pr`
- Save project session: `<leader>ps`
- Load project session: `<leader>pl`
- Recent files in current project: `<leader>fp`

## Theme (Catppuccin Mocha)

- Default colorscheme: **Catppuccin Mocha** (not `habamax`).
- Shared palette with terminal stack:
  - `ghostty/config` — background `#1e1e2e`, text `#cdd6f4`, mauve accent `#cba6f7`
  - `tmux.conf` — inline `@thm_*` Mocha palette (no TPM catppuccin plugin), current window mauve
  - `nvim/lua/config/palette.lua` — same hex pins for nvim chrome / docs
- Plugin: `catppuccin.nvim` via vim.pack; statusline/float borders use surface0 + mauve accents.

## Notes

- Neovim is the **code** editing surface. Agent orchestration lives outside the editor (Pi/Claude/workflow). Diff product review can use Hunk as an external CLI/tmux pane when needed — it is not an in-nvim cockpit.
- Buffers, `bufferline`, the right sidebar, and Telescope are the default navigation model.
- Target Neovim version is `0.12.2+`.
- `:EtabliDoctor` checks the dotfiles config root separately from the current project root, so Pi symlink checks remain valid from any repo.
- LSP startup is guarded by executable checks; missing optional fullstack servers are reported as `WARN` by `:EtabliDoctor` instead of failing on file open.
- Files from 512 KiB to 3 MiB keep immediate native syntax coloring while skipping LSP, formatting, and Tree-sitter work; files above 3 MiB also disable syntax as an explicit responsiveness safeguard.
- Copilot uses Neovim native LSP inline completion when `copilot-language-server` is installed; it is not part of the `nvim-cmp` menu. Project toggles are stored under `stdpath("state")/etabli/copilot.json`.
- File icons assume a Nerd Font-capable terminal; repo defaults use `CaskaydiaMono Nerd Font` with editor ligatures disabled.
