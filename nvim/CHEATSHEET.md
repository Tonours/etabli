# Neovim Cheatsheet

Leader: `<Space>`

## Find

- files: `<leader><space>` or `<leader>ff`
- grep: `<leader>/` or `<leader>fg`
- current word: `<leader>fw`
- buffers: `<leader>.` or `<leader>fb`
- recent files: `<leader>fr`
- project recent files: `<leader>fp`

## Explorer

- toggle explorer: `<leader>ft`
- focus explorer: `<leader>fe`
- in explorer:
  - open file in new tab: `<CR>`, `o`, double click
  - expand/collapse directory: `<CR>`, `o`, double click
  - new tab directly: `<C-t>`

## Projects / worktrees

- projects: `<leader>pp`
- worktrees: `<leader>pw`
- new worktree: `<leader>pW`
- root current buffer: `<leader>pr`
- save session: `<leader>ps`
- load session: `<leader>pl`
- project info: `<leader>pi`
- ADE group aliases: `<leader>as`, `<leader>au`, `<leader>an`, `<leader>ad`, `<leader>af`, `<leader>am`, `<leader>ap`, `<leader>ah`, `<leader>ar`
- ADE status: `<leader>pa` or `:ADEStatus`
- ADE resume: `<leader>pA` or `:ADEResume`
- ADE next: `<leader>pn` or `:ADENext`
- ADE doctor: `<leader>pd` or `:ADEDoctor`
- ADE refresh review: `<leader>pf` or `:ADERefreshReview`
- ADE mode: `<leader>pm` or `:ADEMode [simple|standard|option-compare]`
- ADE open plan: `<leader>po` or `:ADEOpenPlan`
- ADE handoff: `<leader>ph` or `:ADEHandoff`
- ADE review: `<leader>pR` or `:ADEReview`

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
- `:ADEStatus` shows stored review blockers, runtime state, handoff presence, and parse warnings for the current worktree.
- `:ADENext` gives the next bounded ADE action; it uses stored review state for speed, so open the inbox or run `:ADERefreshReview` for live diff accuracy and stale-blocker refresh.
- `:ADEDoctor` is the plumbing check when the cockpit feels suspicious.
- `:ADEMode` is explicit posture, not auto-detection; unset defaults to `standard`.
- Worktree picker: press `<C-n>` to create a new worktree.
