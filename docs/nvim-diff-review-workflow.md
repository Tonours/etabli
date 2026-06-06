# Neovim Diff Review Workflow

This review flow treats Git hunks as first-class review units inside Neovim.

## Current hunk actions

- `<leader>rh` preview the current hunk with its saved note and status
- `<leader>ra` add a GitHub PR-style review comment on the current line
- visual `<leader>ra` add a review comment on the selected line range
- `<leader>rr` resolve the current review conversation
- `<leader>rs` choose a review status for the current hunk
- `<leader>rA` accept the current hunk directly
- `<leader>rV` mark the current hunk as reviewed without accepting it
- `<leader>rt` start a local draft review transaction
- `<leader>rT` preview the active review transaction
- `<leader>rl` toggle inline review annotations in file buffers
- `<leader>ro` expand or collapse the inline review thread under the cursor
- `<leader>rg` compare agent review findings for the current hunk
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
- `:ReviewMarkReviewed [on|off|toggle]`
- `:ReviewStart`
- `:ReviewPreview`
- `:ReviewSubmit [comment|approve|request-changes]`
- `:ReviewExport [markdown|json]`
- `:ReviewInlineAnnotations [on|off|refresh|toggle|expand|compact]`
- `:ReviewClaude [revise|explain|review]`
- `:ReviewPi [revise|explain|review]`
- `:ReviewIngestClaude [file]`
- `:ReviewIngestPi [file]`
- `:ReviewCompareAgents`

Inline annotations show unresolved review conversations on the live file line or selected line range, similar to GitHub PR file review comments. They are rendered with extmarks and signs, so they do not modify the file. To keep large reviews readable and fast, conversations render as compact end-of-line markers by default. Use `<leader>ro` or `:ReviewInlineAnnotations expand` to expand the thread under the cursor, and `:ReviewInlineAnnotations compact` to collapse the current buffer again. Older hunk-level notes are still shown as a compact end-of-line fallback.

Multi-line comments must stay inside one reviewable git hunk. If a visual selection crosses hunk boundaries, the review command refuses the comment instead of storing an ambiguous anchor.

Use `:ReviewStart` before annotating when you want GitHub-style draft review behavior. While a transaction is active, `ReviewAnnotate` stores pending comments in the local transaction instead of immediately adding submitted comments. `:ReviewPreview` shows the pending review, `:ReviewExport markdown|json` opens an export buffer, and `:ReviewSubmit comment|approve|request-changes` commits the pending comments into local review state. Submission refuses stale draft hunks when the diff changed before submit.

Note: current-hunk review uses `git diff` as the source of truth. Save the buffer first if you want cursor-to-hunk matching to stay accurate.

## Review inbox

- `<leader>ri` opens a Telescope inbox for staged and unstaged hunks in the current repo
- `:ReviewInbox [status|filter]` opens the same inbox with an optional status filter such as `needs-rework` or an attention filter such as `attention`
- mark one or more entries with Telescope multi-select (`<Tab>` / `<S-Tab>`) before triggering a provider action if you want a batch prompt from the inbox
- default `<CR>` opens a diff tab for the selected live hunk, with the current file on the right when available
- `<C-a>` adds a review comment at the selected hunk start line
- `<C-s>` changes the selected hunk status
- `r` or `<C-g>` marks the selected hunk, or all marked hunks, as reviewed without accepting them
- `<C-y>` accepts the selected hunk, or all marked hunks
- `<C-c>` launches Claude directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-p>` launches Pi directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-r>` refreshes the inbox after you changed the diff outside the picker
- `?` opens an overlay help panel for the inbox shortcuts; when you close it with `q` or `Esc`, the review inbox is reopened

The inbox labels each entry with stable columns for attention marker, scope (`WORKING`, `STAGED`, `STALE`), review status, unresolved comment count or note marker, reviewed state, and file location. Statuses are highlighted, and the preview starts with file/status/attention/comment metadata before the diff. After you comment on a hunk, mark it reviewed, or change its status from the picker, the inbox reopens automatically so you can continue reviewing.

Attention filters:

- `:ReviewInbox attention` shows hunks that still need review action.
- `:ReviewInbox unresolved` shows hunks with unresolved review comments.
- `:ReviewInbox changed-since-review` shows hunks whose patch changed after they were marked reviewed.
- `:ReviewInbox reviewed:false` shows hunks that are still open.
- `:ReviewInbox reviewed:true` shows hunks already marked reviewed.
- `:ReviewInbox current-file` shows review items for the current buffer path.

The inbox keeps a short-lived local cache for merged review items. This speeds up repeated opens during the same review pass without weakening review correctness: writes, deletes, directory changes, shell commands, focus changes, review status updates, and review notes all invalidate the cache.

By default, stale entries in `new`, `accepted`, or `ignore` are hidden from the inbox to avoid noise after a revert or commit. Actionable stale entries such as `needs-rework` or `question` still stay visible by default. If you explicitly filter `:ReviewInbox new`, `:ReviewInbox accepted`, or `:ReviewInbox ignore`, those stale entries are still available.

## Batch prompt preparation

- `:ReviewClaudeBatch [status]` prepares one Claude prompt for every live hunk with that status
- `:ReviewPiBatch [status]` prepares one Pi prompt for every live hunk with that status
- `:ReviewClaudeReview [status|all|changed-only]` launches Claude with a first-pass code review prompt for live hunks
- `:ReviewPiReview [status|all|changed-only]` launches Pi with a first-pass code review prompt for live hunks
- `<leader>rbc` prepares the default Claude batch prompt for `needs-rework`
- `<leader>rbp` prepares the default Pi batch prompt for `needs-rework`
- `<leader>rvc` launches the Claude first-pass review for all live hunks
- `<leader>rvp` launches the Pi first-pass review for all live hunks

Both commands default to `needs-rework`, so `:ReviewClaudeBatch` is the quick "prepare all needs-rework hunks" flow.

Review commands default to all live staged and unstaged hunks. Passing a status narrows the review, for example `:ReviewClaudeReview needs-rework`. Passing `changed-only` reviews only hunks that changed after being marked reviewed.

The `review` action is intentionally read-only. It asks the provider to report findings ordered by severity and end with `GO`, `GO WITH NOTES`, or `BLOCK`; it does not ask the provider to edit files.

Import agent review output back into local review state with `:ReviewIngestClaude [file]` or `:ReviewIngestPi [file]`. Without a file argument, the command reads the unnamed register. Imported findings must use the structured labels requested by the review prompt: `severity:`, `file:`, `line:` or `line_range:`, `issue:`, `impact:`, `review_comment:`, and optional `suggested_fix:`. Findings are anchored to live hunks before being stored; unmatched or duplicate findings are skipped. The Inbox shows provider counts such as `C:1` and `P:2`, inline annotations show compact agent markers, and `<leader>rg` or `:ReviewCompareAgents` compares Pi and Claude findings for the current hunk.

## Prompt dispatch behavior

Provider actions do three things:

1. build a deterministic prompt from the selected hunk or batch
2. copy it to the unnamed register and clipboard register when available
3. open a scratch preview and then launch `claude` or `pi` in a terminal tab when the CLI exists

This keeps the flow safe and explicit while removing the manual paste step: the prompt is still visible in the scratch preview and copied to registers, but the CLI also starts with the diff prompt already injected. Provider prompts always launch the interactive CLI without a prompt argument and queue sanitized bracketed terminal paste input instead of using Claude `-p` / `--print` or leaking the full prompt through process arguments.

Provider CLIs are resolved from your environment, so the setup stays portable across machines instead of depending on a single hardcoded local path.

## Local state

Review state is stored outside tracked project files under Neovim state:

- `stdpath("state")/etabli/review`

Entries are keyed by repo root, branch, diff scope, file path, hunk header, and patch hash. Review comments are stored with an id, target line range, body, resolved state, and timestamps.

## Smoke check

Run the isolated Neovim smoke check with:

```bash
tests/nvim-smoke.sh
```

The wrapper sets `XDG_STATE_HOME` to a temporary directory so review and Copilot state checks never write to the user's live Neovim state.
