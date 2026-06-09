# Neovim Cheatsheet

Leader: `<Space>`

## Find

- files: `<leader><space>`, `<leader>ff`, or `Cmd/Ctrl+P`
- command palette: `Cmd/Ctrl+Shift+P` or `:CommandPalette`
- grep: `<leader>/` or `<leader>fg`
- current word: `<leader>fw`
- buffers: `<leader>.` or `<leader>fb`
- find & replace: `<leader>fr`
- recent files: `<leader>fo`
- project recent files: `<leader>fp`

## Projects

- projects: `<leader>pp`
- root current buffer: `<leader>pr`
- save session: `<leader>ps`
- load session: `<leader>pl`
- project info: `<leader>pi`

## Explorer

- focus right sidebar: `<leader>ft`
- reveal current file: `<leader>fe`

## Buffers

- next buffer: `<leader>bn`
- previous buffer: `<leader>bp`
- close buffer: `<leader>bd`

## Tabs

- new tab: `<leader>tn`
- next tab: `<leader>tl`
- previous tab: `<leader>th`
- close tab: `<leader>tx`
- close other tabs: `<leader>to`

## Windows

- vertical split: `<leader>wv`
- horizontal split: `<leader>wh`
- keep only current window: `<leader>wo`
- move left/down/up/right: `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>`

## LSP / code

- definition: `gd`
- references: `gr`
- implementation: `gI` or `<leader>ci`
- hover: `K`
- rename: `<leader>rn`
- code action: `<leader>ca`
- format: `<leader>cf`
- document symbols: `<leader>ss`
- workspace symbols: `<leader>sS`
- Copilot native sign in: `:LspCopilotSignIn`
- Copilot inline: `Tab` or `<A-l>` accept, `<A-]>` next, `<A-[>` previous
- Copilot controls: `:CopilotStatus`, `:CopilotDisable`, `:CopilotEnable`, `:CopilotToggle`
- setup diagnostics: `:EtabliDoctor`

## Diagnostics

- buffer diagnostics: `<leader>dd`
- workspace diagnostics: `<leader>dD`
- line diagnostics: `<leader>dl`
- previous diagnostic: `[d`
- next diagnostic: `]d`

## Review

- inbox: `<leader>ri` or `:ReviewInbox` opens Hunk
- current hunk: `<leader>rh` focuses the current line in Hunk, `<leader>ra` comments the current line/range in an active Hunk session
- sync notes: `<leader>rs` or `:ReviewHunkSync` pulls Hunk notes before close; use `:ReviewHunkSync push` explicitly to rehydrate local notes
- comment editor: `<C-s>`/`ZZ` save, `ZQ`/`q`/`Esc` cancel
- Hunk viewer: `<leader>rH` or `:ReviewHunk` opens `hunk diff --watch`
- Hunk comments: `<leader>rn` next, `<leader>rN` previous
- navigate hunks: `[h` previous, `]h` next
- Claude review: `<leader>rc`, `<leader>rvc`, `:ReviewClaudeReview changed-only` after Hunk is open
- Pi review: `<leader>rp`, `<leader>rvp`, `:ReviewPiReview changed-only` after Hunk is open
- legacy local review commands/keymaps: opt in with `vim.g.etabli_review_legacy_commands = 1` and `vim.g.etabli_review_legacy_keymaps = 1`


## Tip

- Use Neovim as the review and editing surface, not as an agent cockpit.
- Copilot runs through Neovim's native LSP inline completion, not as an `nvim-cmp` source.
- `Tab` first accepts a visible Copilot inline suggestion, then falls back to completion or a literal tab.
- Press `<leader>` to let `which-key` remind you of grouped shortcuts.
- `workflow/spec.md` remains the reference for the broader agent workflow.
