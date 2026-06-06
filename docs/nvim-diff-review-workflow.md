# Neovim Diff Review Workflow

This review flow treats Git hunks as first-class review units inside Neovim.

## Current hunk actions

- `<leader>rh` preview the current hunk with its saved note and status
- `<leader>ra` add a GitHub PR-style review comment on the current line
- visual `<leader>ra` add a review comment on the selected line range
- `<leader>rr` resolve the current review conversation
- `<leader>rs` choose a review status for the current hunk
- `<leader>rA` accept the current hunk directly
- `<leader>rl` toggle inline review annotations in file buffers
- `<leader>rc` build a `revise` prompt for Claude from the current hunk
- `<leader>rC` build an `explain` prompt for Claude from the current hunk
- `<leader>rp` build a `revise` prompt for Pi from the current hunk
- `<leader>rP` build an `explain` prompt for Pi from the current hunk

Equivalent commands:

- `:ReviewCurrentHunk`
- `:ReviewAnnotate`
- `:ReviewResolve`
- `:ReviewStatus [new|accepted|needs-rework|question|ignore]`
- `:ReviewAccept`
- `:ReviewInlineAnnotations [on|off|refresh|toggle]`
- `:ReviewClaude [revise|explain|review]`
- `:ReviewPi [revise|explain|review]`

Inline annotations show unresolved review conversations below the live file line or selected line range, similar to GitHub PR file review comments. They are rendered with extmarks and signs, so they do not modify the file. Older hunk-level notes are still shown as a compact end-of-line fallback.

Multi-line comments must stay inside one reviewable git hunk. If a visual selection crosses hunk boundaries, the review command refuses the comment instead of storing an ambiguous anchor.

Note: current-hunk review uses `git diff` as the source of truth. Save the buffer first if you want cursor-to-hunk matching to stay accurate.

## Review inbox

- `<leader>ri` opens a Telescope inbox for staged and unstaged hunks in the current repo
- `:ReviewInbox [status]` opens the same inbox with an optional status filter such as `needs-rework` or `question`
- mark one or more entries with Telescope multi-select (`<Tab>` / `<S-Tab>`) before triggering a provider action if you want a batch prompt from the inbox
- default `<CR>` opens a diff tab for the selected live hunk, with the current file on the right when available
- `<C-a>` adds a review comment at the selected hunk start line
- `<C-s>` changes the selected hunk status
- `<C-y>` accepts the selected hunk, or all marked hunks
- `<C-c>` launches Claude directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-p>` launches Pi directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-r>` refreshes the inbox after you changed the diff outside the picker
- `?` opens an overlay help panel for the inbox shortcuts; when you close it with `q` or `Esc`, the review inbox is reopened

The inbox labels each entry with stable columns for scope (`WORKING`, `STAGED`, `STALE`), review status, unresolved comment count or note marker, and file location. Statuses are highlighted, and the preview starts with file/status/comment metadata before the diff. After you comment on a hunk or change its status from the picker, the inbox reopens automatically so you can continue reviewing.

The inbox keeps a short-lived local cache for merged review items. This speeds up repeated opens during the same review pass without weakening review correctness: writes, deletes, directory changes, shell commands, focus changes, review status updates, and review notes all invalidate the cache.

By default, stale entries in `new`, `accepted`, or `ignore` are hidden from the inbox to avoid noise after a revert or commit. Actionable stale entries such as `needs-rework` or `question` still stay visible by default. If you explicitly filter `:ReviewInbox new`, `:ReviewInbox accepted`, or `:ReviewInbox ignore`, those stale entries are still available.

## Batch prompt preparation

- `:ReviewClaudeBatch [status]` prepares one Claude prompt for every live hunk with that status
- `:ReviewPiBatch [status]` prepares one Pi prompt for every live hunk with that status
- `:ReviewClaudeReview [status|all]` launches Claude with a first-pass code review prompt for live hunks
- `:ReviewPiReview [status|all]` launches Pi with a first-pass code review prompt for live hunks
- `<leader>rbc` prepares the default Claude batch prompt for `needs-rework`
- `<leader>rbp` prepares the default Pi batch prompt for `needs-rework`
- `<leader>rvc` launches the Claude first-pass review for all live hunks
- `<leader>rvp` launches the Pi first-pass review for all live hunks

Both commands default to `needs-rework`, so `:ReviewClaudeBatch` is the quick "prepare all needs-rework hunks" flow.

Review commands default to all live staged and unstaged hunks. Passing a status narrows the review, for example `:ReviewClaudeReview needs-rework`.

The `review` action is intentionally read-only. It asks the provider to report findings ordered by severity and end with `GO`, `GO WITH NOTES`, or `BLOCK`; it does not ask the provider to edit files.

## Prompt dispatch behavior

Provider actions do three things:

1. build a deterministic prompt from the selected hunk or batch
2. copy it to the unnamed register and clipboard register when available
3. open a scratch preview and then launch `claude` or `pi` in a terminal tab when the CLI exists

This keeps the flow safe and explicit while removing the manual paste step: the prompt is still visible in the scratch preview and copied to registers, but the CLI also starts with the diff prompt already injected. Single-line prompts can be passed as the first CLI message. Review prompts are multi-line, so they launch the interactive CLI without a prompt argument and queue bracketed terminal paste input instead of using Claude `-p` / `--print` or leaking the full prompt through process arguments.

Provider CLIs are resolved from your environment, so the setup stays portable across machines instead of depending on a single hardcoded local path.

## Local state

Review state is stored outside tracked project files under Neovim state:

- `stdpath("state")/etabli/review`

Entries are keyed by repo root, branch, diff scope, file path, hunk header, and patch hash. Review comments are stored with an id, target line range, body, resolved state, and timestamps.

## Smoke check

You can run the review smoke check with:

```bash
XDG_CONFIG_HOME="$PWD" nvim --headless -u "$PWD/nvim/init.lua" "+lua dofile('$PWD/scripts/review_smoke.lua')" +qa
```
