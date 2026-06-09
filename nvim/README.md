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

- Inbox: `<leader>ri` or `:ReviewInbox` opens or reloads Hunk
- Current hunk: `<leader>rh` focuses the current buffer line in Hunk, `<leader>ra` comments the current line or visual range in the active Hunk session
- Sync: `<leader>rs` or `:ReviewHunkSync` pulls live Hunk notes into local persistence before closing Hunk and pushes unresolved local notes back into the active Hunk session
- Comment editor: `<C-s>` or `ZZ` saves a multiline Markdown comment, `ZQ`/`q`/`Esc` cancels
- Hunk viewer: `<leader>rH` or `:ReviewHunk` opens `hunk diff --watch` for the current repo
- Hunk comments: `<leader>rn` / `<leader>rN` navigate next/previous review comment
- Hunk navigation: `[h`, `]h` moves between Git hunks in the file
- Claude: `<leader>rc` or `<leader>rvc` launches a first-pass Hunk review
- Pi: `<leader>rp` or `<leader>rvp` launches a first-pass Hunk review
- First-pass review: `<leader>rvc` Claude, `<leader>rvp` Pi, `:ReviewClaudeReview changed-only` or `:ReviewPiReview changed-only` for changed hunks

Legacy local review commands and keymaps are opt-in. Set `vim.g.etabli_review_legacy_commands = 1` and `vim.g.etabli_review_legacy_keymaps = 1` before loading this config if you need the old local inbox, statuses, draft transactions, agent ingest, or suggestion tracking while Hunk persistence gaps remain.

Notes:

- Review state is stored outside the repo under `stdpath("state")/etabli/review`
- Hunk is the terminal review-first diff viewer installed from `hunkdiff`; use it for full changeset walkthroughs and live agent-facing review sessions
- Hunk notes are not durable after closing Hunk in the current tested version; run `:ReviewHunkSync pull` before closing a review session
- Local inline annotations are legacy UI and disabled by default

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
