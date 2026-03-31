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
- ADE resume: `<leader>pA` or `:ADEResume`
- ADE next: `<leader>pn` or `:ADENext`
- ADE doctor: `<leader>pd` or `:ADEDoctor`
- ADE refresh review: `<leader>pf` or `:ADERefreshReview`
- ADE mode: `<leader>pm` or `:ADEMode [simple|standard|option-compare]`
- ADE plan: `<leader>po` or `:ADEOpenPlan`
- ADE handoff: `<leader>ph` or `:ADEHandoff`
- ADE review: `<leader>pR` or `:ADEReview`

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

ADE cockpit:
- `:ADEStatus` shows plan, stored review blockers, runtime, handoff presence, and parse warnings
- `:ADEResume` reloads the current worktree session when available, then summarizes the current ADE context
- `:ADENext` shows the next bounded ADE action for the current worktree
- `:ADEDoctor` reports `PASS|WARN|FAIL` checks for repo, worktree, session, plan, runtime, review, handoff, and mode
- `:ADERefreshReview` runs the explicit live diff refresh path and updates the current review blocker summary
- `:ADEMode` shows or sets the current ADE operating mode (`simple`, `standard`, `option-compare`)
- `:ADEOpenPlan` opens `PLAN.md` in the current buffer and warns if the file is partial/invalid
- `:ADEHandoff` opens `.pi/handoff-implement.md`, then `.pi/handoff.md`
- `:ADEReview` opens the review inbox directly
- ADE also exports a derived snapshot for the current worktree at `~/.pi/status/<sanitized-cwd>.ade.json` so Pi and Claude can read the same bounded status without recomputing ADE logic
- run `./scripts/test-ade-local.sh` from repo root to revalidate the shared ADE surface before commit

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
- ADE summary uses the stored review state for quick counts; brand-new hunks only appear once you open the inbox, and stored blockers may still be stale until `:ADERefreshReview` or the inbox refresh path runs
- ADE mode is operator-selected posture, not auto-detected truth; the default when unset is `standard`
- the exported ADE snapshot is display state only: it stays cheap, does not trigger live review refresh by itself, and should be treated as a shared read-only projection

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
