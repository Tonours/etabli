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
- New worktree: `<leader>pW`
- OPS group aliases: `<leader>a...`
- Project info: `<leader>pi` or `:ProjectInfo`
- OPS status: `<leader>pa` or `:OPSStatus`
- OPS resume: `<leader>pA` or `:OPSResume`
- OPS next: `<leader>pn` or `:OPSNext`
- OPS doctor: `<leader>pd` or `:OPSDoctor`
- OPS refresh review: `<leader>pf` or `:OPSRefreshReview`
- OPS mode: `<leader>pm` or `:OPSMode [simple|standard|option-compare]`
- OPS plan: `<leader>po` or `:OPSOpenPlan`
- OPS handoff: `<leader>ph` or `:OPSHandoff`
- OPS review: `<leader>pR` or `:OPSReview`

Long-form aliases stay available:
- `<leader>ff`, `<leader>fg`, `<leader>fb`

## Project workflow

- Re-root to current buffer: `<leader>pr`
- New worktree: `<leader>pW`
- Save project session: `<leader>ps`
- Load project session: `<leader>pl`
- Recent files in current project: `<leader>fp`

Statusline:
- `󰉋 name` = project
- ` branch` = worktree
- `•` = session exists
- `+` = session exists, context changed since last save
- `OPS ...` = current plan/runtime snapshot for the current cwd

OPS cockpit:
- top-level OPS aliases now live under `<leader>a...` for easier grouping in which-key (`as`, `au`, `an`, `ad`, `af`, `am`, `ap`, `ah`, `ar`)
- `:OPSStatus` shows the current task, plan, stored review blockers, runtime, handoff presence, and parse warnings
- `:OPSResume` reloads the current worktree session when available, then summarizes the current task/OPS context
- `:OPSNext` shows the next bounded OPS action for the current worktree
- `:OPSDoctor` reports `PASS|WARN|FAIL` checks for repo, worktree, session, plan, runtime, review, handoff, and mode
- `:OPSRefreshReview` runs the explicit live diff refresh path and updates the current review blocker summary
- `:OPSMode` shows or sets the current OPS operating mode (`simple`, `standard`, `option-compare`)
- `:OPSOpenPlan` opens `PLAN.md` in the current buffer and warns if the file is partial/invalid
- `:OPSHandoff` opens `.pi/handoff-implement.md`, then `.pi/handoff.md`
- `:OPSReview` opens the review inbox directly
- OPS writes one lightweight per-worktree task projection to `~/.pi/status/<sanitized-cwd>.task.json`
- OPS also exports a derived snapshot for the current worktree at `~/.pi/status/<sanitized-cwd>.ops.json` so Pi and Claude can read the same bounded status without recomputing OPS logic
- run `./scripts/test-ops-local.sh` from repo root to revalidate the shared OPS surface before commit

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
- OPS summary uses the stored review state for quick counts; brand-new hunks only appear once you open the inbox, and stored blockers may still be stale until `:OPSRefreshReview` or the inbox refresh path runs
- OPS mode is operator-selected posture, not auto-detected truth; the default when unset is `standard`
- the exported OPS task-state + snapshot are display state only: they stay cheap, do not trigger live review refresh by themselves, and should be treated as shared read-only projections

## Window policy

- Single-pane by default
- Splits only on purpose: `<leader>wv`, `<leader>wh`
- Buffers are primary; explorer opens files in tabs
- Explorer is visible support, not the main navigation model

## Notes

- Use `cw` to create/open worktrees.
- In the worktree picker, press `<C-n>` to create a new worktree.
- Use Neovim to switch between tracked projects/worktrees.
- Neovim is the cockpit, not the workflow brain: the shared execution model lives in `workflow/operating-model.md`.
- A practical zero-idle loop is: worker running in one worktree, review inbox / QA prep / option comparison running in parallel outside that critical path.
- `which-key` is enabled in a minimal mode for leader-map recall.
