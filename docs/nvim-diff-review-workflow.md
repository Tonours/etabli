# Neovim Diff Review Workflow

This review flow treats Git hunks as first-class review units inside Neovim.

## Current hunk actions

- `<leader>rh` preview the current hunk with its saved note and status
- `<leader>ra` add or edit a note for the current hunk
- `<leader>rs` choose a review status for the current hunk
- `<leader>rc` build a `revise` prompt for Claude from the current hunk
- `<leader>rC` build an `explain` prompt for Claude from the current hunk
- `<leader>rp` build a `revise` prompt for Pi from the current hunk
- `<leader>rP` build an `explain` prompt for Pi from the current hunk

Equivalent commands:

- `:ReviewCurrentHunk`
- `:ReviewAnnotate`
- `:ReviewStatus [new|accepted|needs-rework|question|ignore]`
- `:ReviewClaude [revise|explain]`
- `:ReviewPi [revise|explain]`

Note: current-hunk review uses `git diff` as the source of truth. Save the buffer first if you want cursor-to-hunk matching to stay accurate.

## Review inbox

- `<leader>ri` opens a Telescope inbox for staged and unstaged hunks in the current repo
- `:ReviewInbox [status]` opens the same inbox with an optional status filter such as `needs-rework` or `question`
- default `<CR>` jumps to the selected hunk location
- `<C-a>` annotates the selected hunk
- `<C-s>` changes the selected hunk status
- `<C-c>` prepares a Claude `revise` prompt for the selected hunk
- `<C-p>` prepares a Pi `revise` prompt for the selected hunk
- `<C-r>` refreshes the inbox after you changed the diff outside the picker
- `?` in normal mode opens a short help buffer for the inbox shortcuts

The inbox labels each entry with a clearer scope marker (`WORKING`, `STAGED`, `STALE`), review status, and a count summary in the picker title. After you annotate a hunk or change its status from the picker, the inbox reopens automatically so you can continue reviewing.

## Batch prompt preparation

- `:ReviewClaudeBatch [status]` prepares one Claude prompt for every live hunk with that status
- `:ReviewPiBatch [status]` prepares one Pi prompt for every live hunk with that status

Both commands default to `needs-rework`, so `:ReviewClaudeBatch` is the quick "prepare all needs-rework hunks" flow.

## Prompt dispatch behavior

Provider actions do three things:

1. build a deterministic prompt from the selected hunk
2. copy it to the unnamed register and clipboard register when available
3. open a scratch preview and then launch `claude` or `pi` in a terminal tab if the CLI exists

This keeps the first version safe and explicit: the prompt is always visible before you paste or send it. Batch commands use the same preview/copy/terminal flow, but include every matching hunk in a single prompt.

## Local state

Review state is stored outside tracked project files under Neovim state:

- `stdpath("state")/etabli/review`

Entries are keyed by repo root, branch, diff scope, file path, hunk header, and patch hash.

## Smoke check

You can run the review smoke check with:

```bash
XDG_CONFIG_HOME="$PWD" nvim --headless -u "$PWD/nvim/init.lua" "+lua dofile('$PWD/scripts/review_smoke.lua')" +qa
```
