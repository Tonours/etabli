# Neovim Diff Review Workflow

This review flow treats Git hunks as first-class review units inside Neovim.

## Current hunk actions

- `<leader>rh` preview the current hunk with its saved note and status
- `<leader>ra` add or edit a note for the current hunk
- `<leader>rs` choose a review status for the current hunk
- `<leader>rA` accept the current hunk directly
- `<leader>rc` build a `revise` prompt for Claude from the current hunk
- `<leader>rC` build an `explain` prompt for Claude from the current hunk
- `<leader>rp` build a `revise` prompt for Pi from the current hunk
- `<leader>rP` build an `explain` prompt for Pi from the current hunk

Equivalent commands:

- `:ReviewCurrentHunk`
- `:ReviewAnnotate`
- `:ReviewStatus [new|accepted|needs-rework|question|ignore]`
- `:ReviewAccept`
- `:ReviewClaude [revise|explain]`
- `:ReviewPi [revise|explain]`

Note: current-hunk review uses `git diff` as the source of truth. Save the buffer first if you want cursor-to-hunk matching to stay accurate.

## Review inbox

- `<leader>ri` opens a Telescope inbox for staged and unstaged hunks in the current repo
- `:ReviewInbox [status]` opens the same inbox with an optional status filter such as `needs-rework` or `question`
- mark one or more entries with Telescope multi-select (`<Tab>` / `<S-Tab>`) before triggering a provider action if you want a batch prompt from the inbox
- default `<CR>` opens a diff tab for the selected live hunk, with the current file on the right when available
- `<C-a>` annotates the selected hunk
- `<C-s>` changes the selected hunk status
- `<C-y>` accepts the selected hunk, or all marked hunks
- `<C-c>` launches Claude directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-p>` launches Pi directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-r>` refreshes the inbox after you changed the diff outside the picker
- `?` opens an overlay help panel for the inbox shortcuts; when you close it with `q` or `Esc`, the review inbox is reopened

The inbox labels each entry with a clearer scope marker (`WORKING`, `STAGED`, `STALE`), review status, and a count summary in the picker title. Shortcut hints are split between the results header and preview header so they stay readable. After you annotate a hunk or change its status from the picker, the inbox reopens automatically so you can continue reviewing.

By default, stale entries in `new`, `accepted`, or `ignore` are hidden from the inbox to avoid noise after a revert or commit. Actionable stale entries such as `needs-rework` or `question` still stay visible by default. If you explicitly filter `:ReviewInbox new`, `:ReviewInbox accepted`, or `:ReviewInbox ignore`, those stale entries are still available.

## Batch prompt preparation

- `:ReviewClaudeBatch [status]` prepares one Claude prompt for every live hunk with that status
- `:ReviewPiBatch [status]` prepares one Pi prompt for every live hunk with that status
- `<leader>rbc` prepares the default Claude batch prompt for `needs-rework`
- `<leader>rbp` prepares the default Pi batch prompt for `needs-rework`

Both commands default to `needs-rework`, so `:ReviewClaudeBatch` is the quick "prepare all needs-rework hunks" flow.

## Prompt dispatch behavior

Provider actions do three things:

1. build a deterministic prompt from the selected hunk
2. copy it to the unnamed register and clipboard register when available
3. open a scratch preview and then launch `claude` or `pi` in a terminal tab with that prompt passed directly as the first message when the CLI exists

This keeps the flow safe and explicit while removing the manual paste step: the prompt is still visible in the scratch preview and copied to registers, but the CLI also starts with the diff prompt already injected. Batch commands use the same preview/copy/direct-launch flow, but include every matching hunk in a single prompt.

Provider CLIs are resolved from your environment (`PATH`, plus `NVM_DIR` for Copilot's Node lookup when relevant), so the setup stays portable across machines instead of depending on a single hardcoded local path.

## Local state

Review state is stored outside tracked project files under Neovim state:

- `stdpath("state")/etabli/review`

Entries are keyed by repo root, branch, diff scope, file path, hunk header, and patch hash.

## Smoke check

You can run the review smoke check with:

```bash
XDG_CONFIG_HOME="$PWD" nvim --headless -u "$PWD/nvim/init.lua" "+lua dofile('$PWD/scripts/review_smoke.lua')" +qa
```
