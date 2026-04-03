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
- in find & replace: explicit `Search`, `Replace`, `Paths` inputs in an overlay; `<Tab>` / `<S-Tab>` switch inputs; `q` close; `?` help; inside the grug-far buffer, `<leader>R` replaces all

## Explorer

- toggle explorer: `<leader>ft`
- focus explorer: `<leader>fe`
- in explorer:
  - open file in new tab: `<CR>`, `o`, double click
  - expand/collapse directory: `<CR>`, `o`, double click
  - new tab directly: `<C-t>`

## Projects / OPS

- projects: `<leader>pp`
- root current buffer: `<leader>pr`
- save session: `<leader>ps`
- load session: `<leader>pl`
- project info: `<leader>pi`
- OPS group aliases: `<leader>as`, `<leader>au`, `<leader>an`, `<leader>ad`, `<leader>af`, `<leader>am`, `<leader>ap`, `<leader>ah`, `<leader>ar`
- OPS status: `<leader>pa` or `:OPSStatus`
- OPS resume: `<leader>pA` or `:OPSResume`
- OPS next: `<leader>pn` or `:OPSNext`
- OPS doctor: `<leader>pd` or `:OPSDoctor`
- OPS refresh review: `<leader>pf` or `:OPSRefreshReview`
- OPS mode: `<leader>pm` or `:OPSMode [simple|standard]`
- OPS open plan: `<leader>po` or `:OPSOpenPlan`
- OPS handoff: `<leader>ph` or `:OPSHandoff`
- OPS review: `<leader>pR` or `:OPSReview`

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

## Diagnostics

- buffer diagnostics: `<leader>dd`
- workspace diagnostics: `<leader>dD`
- line diagnostics: `<leader>dl`
- previous diagnostic: `[d`
- next diagnostic: `]d`

## Review

- inbox: `<leader>ri` or `:ReviewInbox [status]`
- current hunk: `<leader>rh` preview, `<leader>ra` annotate, `<leader>rs` status, `<leader>rA` accept
- Claude hunk actions: `<leader>rc` revise, `<leader>rC` explain
- Pi hunk actions: `<leader>rp` revise, `<leader>rP` explain
- batch rework: `<leader>rbc`, `<leader>rbp`
- in inbox: `<Tab>` / `<S-Tab>` mark, `<CR>` open diff, `<C-a>` annotate, `<C-s>` status, `<C-y>` accept, `<C-c>` Claude, `<C-p>` Pi, `<C-r>` refresh, `?` help

## Multi-cursor

- add next occurrence: `<C-n>` or `<leader>mn`
- add cursor down/up: `<leader>mj`, `<leader>mk`
- original vertical cursor shortcuts: `<C-Down>`, `<C-Up>`
- skip current match: `q`
- remove current cursor: `Q`
- switch mode: `<Tab>`

## Tip

- `which-key` shows leader mappings after pressing `<Space>`.
- Use `workflow/operating-model.md` for the daily Claude + Pi execution modes.
- Keep Neovim as cockpit: while one worker runs, use review inbox, project info, and QA prep instead of watching the agent stream.
- `:OPSStatus` shows stored review blockers, runtime state, handoff presence, and parse warnings for the current cwd.
- `:OPSNext` gives the next bounded OPS action; it uses stored review state for speed, so open the inbox or run `:OPSRefreshReview` for live diff accuracy and stale-blocker refresh.
- `:OPSDoctor` is the plumbing check when the cockpit feels suspicious.
- `:OPSMode` is explicit posture, not auto-detection; unset defaults to `standard`.
