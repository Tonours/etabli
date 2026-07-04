# Neovim

Review-first daily-driver config.

Good fit: TS/JS, React, Ember, Tailwind, CSS/SCSS, JSON/YAML, PHP.

Quick ref: `nvim/CHEATSHEET.md`

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

- Inbox: `<leader>ri` or `:ReviewInbox` opens or reloads Hunk
- Current hunk: `<leader>rh` focuses the current buffer line in Hunk, `<leader>ra` comments the current line or visual range in the active Hunk session; if no session exists, it opens Hunk first
- Comment editor: `<C-s>` or `ZZ` saves a multiline Markdown comment, `ZQ`/`q`/`Esc` cancels
- Hunk viewer: `<leader>rH` or `:ReviewHunk` opens `hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg` for the current repo
- Context rail: `<leader>rx` or `:ReviewContext` opens the right-side Hunk thread/file/checks rail; it opens automatically on wide terminals
- Hunk comments: `<leader>rj` / `<leader>rk` navigate next/previous review comment
- Hunk navigation: `[h`, `]h` moves between Git hunks in the file
- Claude: `<leader>rc` launches a first-pass Hunk review
- Pi: `<leader>rp` launches a first-pass Hunk review
- First-pass review: `:ReviewClaudeReview changed-only` or `:ReviewPiReview changed-only` for changed hunks; if no Hunk session exists, the command opens Hunk first and you rerun it after the session is ready

Notes:

- Hunk owns review sessions and notes; there is no local mirror or sync step
- Hunk is the terminal review-first diff viewer installed from `hunkdiff`; use it for full changeset walkthroughs and live agent-facing review sessions
- Review dispatch never checks `PLAN.md`/READY state; plan gating applies to implementation only (`workflow/spec.md`)

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
