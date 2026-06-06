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

- inbox: `<leader>ri` or `:ReviewInbox [status]`
- current hunk: `<leader>rh` preview, `<leader>ra` comment line/range, `<leader>rr` resolve, `<leader>rs` status, `<leader>rA` accept
- inline annotations: `<leader>rl`
- navigate hunks: `[h` previous, `]h` next
- Claude hunk actions: `<leader>rc` revise, `<leader>rC` explain
- Pi hunk actions: `<leader>rp` revise, `<leader>rP` explain
- batch rework: `<leader>rbc`, `<leader>rbp`
- first-pass review: `<leader>rvc` Claude, `<leader>rvp` Pi
- in inbox: `<Tab>` / `<S-Tab>` mark, `<CR>` open diff, `<C-a>` annotate, `<C-s>` status, `<C-y>` accept, `<C-c>` Claude, `<C-p>` Pi, `<C-r>` refresh, `?` help


## Tip

- Use Neovim as the review and editing surface, not as an agent cockpit.
- Copilot runs through Neovim's native LSP inline completion, not as an `nvim-cmp` source.
- `Tab` first accepts a visible Copilot inline suggestion, then falls back to completion or a literal tab.
- Press `<leader>` to let `which-key` remind you of grouped shortcuts.
- `workflow/spec.md` remains the reference for the broader agent workflow.
