# Neovim

Review-first daily-driver config.

Good fit: TS/JS, React, Ember, Tailwind, CSS/SCSS, JSON/YAML, PHP.

Quick ref: `nvim/CHEATSHEET.md`

Detailed review flow: `docs/nvim-diff-review-workflow.md`

## Core flow

- Files: `<leader><space>` or `Cmd/Ctrl+P`
- Command palette: `Cmd/Ctrl+Shift+P` or `:CommandPalette`
- Grep: `<leader>/`
- Find & replace: `<leader>fr`
- Buffers: `<leader>.`
- Projects: `<leader>pp`
- Project info: `<leader>pi` or `:ProjectInfo`
- Sidebar: `neo-tree` stays on the right with file icons, keeps its width when the last editor buffer closes, `<leader>ft` focuses it, `<leader>fe` reveals the current file
- Tabs: `bufferline` shows open buffers across the top
- Shortcut help: press `<leader>` and wait briefly for `which-key`

## Review flow

- Inbox: `<leader>ri` or `:ReviewInbox [status]`
- Current hunk: `<leader>rh` preview, `<leader>ra` annotate, `<leader>rs` status, `<leader>rA` accept
- Hunk navigation: `[h`, `]h`
- Claude: `<leader>rc` revise, `<leader>rC` explain
- Pi: `<leader>rp` revise, `<leader>rP` explain
- Batch rework: `<leader>rbc`, `<leader>rbp`

Inbox shortcuts:

- Mark entries: `<Tab>` / `<S-Tab>`
- Open diff: `<CR>`
- Annotate / status / accept: `<C-a>`, `<C-s>`, `<C-y>`
- Launch provider directly with selected diff: `<C-c>` for Claude, `<C-p>` for Pi
- Refresh / help: `<C-r>`, `?`

Notes:

- Review state is stored outside the repo under `stdpath("state")/etabli/review`
- Stale `new`, `accepted`, and `ignore` entries are hidden by default in the inbox to reduce noise
- Closing the help overlay reopens the review inbox automatically

## Project workflow

- Re-root to current buffer: `<leader>pr`
- Save project session: `<leader>ps`
- Load project session: `<leader>pl`
- Recent files in current project: `<leader>fp`


## Code workflow

- Symbols: `<leader>ss`, `<leader>sS`
- Diagnostics: `<leader>dd`, `<leader>dD`, `<leader>dl`, `[d`, `]d`
- Format: `<leader>cf`
- Implementation: `gI` or `<leader>ci`
- Rename: `<leader>rn`
- Code action: `<leader>ca`
- Copilot native: `:LspCopilotSignIn` from a project buffer, `Tab` or `<A-l>` accept inline suggestion, `<A-]>` / `<A-[>` cycle suggestions
- Copilot controls: `:CopilotStatus`, `:CopilotDisable`, `:CopilotEnable`, `:CopilotToggle`
- Setup doctor: `:EtabliDoctor`

## Notes

- Neovim is the review and editing surface; agent orchestration lives outside the editor.
- Buffers, `bufferline`, the right sidebar, and Telescope are the default navigation model.
- Theme is the builtin `habamax`.
- Target Neovim version is `0.12.2+`.
- `:EtabliDoctor` checks the dotfiles config root separately from the current project root, so Pi symlink checks remain valid from any repo.
- LSP startup is guarded by executable checks; missing optional fullstack servers are reported as `WARN` by `:EtabliDoctor` instead of failing on file open.
- Copilot uses Neovim native LSP inline completion when `copilot-language-server` is installed; it is not part of the `nvim-cmp` menu. Project toggles are stored under `stdpath("state")/etabli/copilot.json`.
- File icons assume a Nerd Font-capable terminal; repo defaults use `CaskaydiaMono Nerd Font` with editor ligatures disabled.
