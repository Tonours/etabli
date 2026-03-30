# Neovim

Focused daily-driver config.

Good fit: TS/JS, React, Ember, Tailwind, CSS/SCSS, JSON/YAML, PHP.

Quick ref: `nvim/CHEATSHEET.md`

Detailed review flow: `docs/nvim-diff-review-workflow.md`

## Core flow

- Files: `<leader><space>`
- Grep: `<leader>/`
- Buffers: `<leader>.`
- Explorer: `<leader>ft`, `<leader>fe`
- Projects: `<leader>pp`
- Worktrees: `<leader>pw`
- Project info: `<leader>pi` or `:ProjectInfo`
- ADE status: `<leader>pa` or `:ADEStatus`

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
- `ADE ...` = current plan/runtime snapshot for the current cwd

## Code workflow

- Symbols: `<leader>ss`, `<leader>sS`
- Diagnostics: `<leader>dd`, `<leader>dD`, `<leader>dl`, `[d`, `]d`
- Format: `<leader>cf`
- Implementation: `gI` or `<leader>ci` (buffer-local, LSP)
- Rename: `<leader>rn` (buffer-local, LSP)
- Code action: `<leader>ca` (buffer-local, LSP)
- Multi-cursor: `<C-n>` or `<leader>mn` next occurrence, `<leader>mj` / `<leader>mk` add vertical cursors

## Diff review workflow

- Inbox: `<leader>ri` or `:ReviewInbox [status]`
- Current hunk: `<leader>rh` preview, `<leader>ra` annotate, `<leader>rs` status, `<leader>rA` accept
- LLM actions: `<leader>rc` / `<leader>rC` for Claude revise/explain, `<leader>rp` / `<leader>rP` for Pi revise/explain
- Batch rework: `<leader>rbc`, `<leader>rbp`, `:ReviewClaudeBatch [status]`, `:ReviewPiBatch [status]`

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

## Window policy

- Single-pane by default
- Splits only on purpose: `<leader>wv`, `<leader>wh`
- Buffers are primary; explorer opens files in tabs
- Explorer is visible support, not the main navigation model

## Notes

- Use `cw` to create/open worktrees.
- Use Neovim to switch between tracked projects/worktrees.
- Neovim is the cockpit, not the workflow brain: the shared execution model lives in `workflow/operating-model.md`.
- A practical zero-idle loop is: worker running in one worktree, review inbox / QA prep / option comparison running in parallel outside that critical path.
- `which-key` is enabled in a minimal mode for leader-map recall.
