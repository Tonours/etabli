# Neovim Diff Review Workflow

This review flow uses Hunk as the default review surface for Git hunks inside Neovim.

## Current hunk actions

- `<leader>rh` focus the current file and line in the live Hunk review when a session exists, or open Hunk otherwise
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
- `<leader>rH` open or reload Hunk's terminal review viewer for the current repo
- `<leader>rg` compare agent review findings for the current hunk
- `<leader>rS` safely preview a suggested change for the current hunk
- `<leader>rc` build a `revise` prompt for Claude from the current hunk
- `<leader>rC` build an `explain` prompt for Claude from the current hunk
- `<leader>rp` build a `revise` prompt for Pi from the current hunk
- `<leader>rP` build an `explain` prompt for Pi from the current hunk

Equivalent commands:

- `:ReviewCurrentHunk`
- `:ReviewLegacyCurrentHunk`
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
- `:ReviewHunk [diff|show]`
- `:ReviewLegacyInbox [status|filter]`
- `:ReviewClaude [revise|explain|review]`
- `:ReviewPi [revise|explain|review]`
- `:ReviewIngestClaude [file]`
- `:ReviewIngestPi [file]`
- `:ReviewCompareAgents`
- `:ReviewSuggestionPreview`
- `:ReviewSuggestionStatus [open|applied|rejected|resolved]`

Inline annotations show unresolved review conversations on the live file line or selected line range, similar to GitHub PR file review comments. They are rendered with extmarks and signs, so they do not modify the file. To keep large reviews readable and fast, conversations render as compact end-of-line markers by default. Use `<leader>ro` or `:ReviewInlineAnnotations expand` to expand the thread under the cursor, and `:ReviewInlineAnnotations compact` to collapse the current buffer again. Older hunk-level notes are still shown as a compact end-of-line fallback.

Multi-line comments must stay inside one reviewable git hunk. If a visual selection crosses hunk boundaries, the review command refuses the comment instead of storing an ambiguous anchor.

Use `:ReviewStart` before annotating when you want GitHub-style draft review behavior. While a transaction is active, `ReviewAnnotate` stores pending comments in the local transaction instead of immediately adding submitted comments. `:ReviewPreview` shows the pending review, `:ReviewExport markdown|json` opens an export buffer, and `:ReviewSubmit comment|approve|request-changes` commits the pending comments into local review state. Submission refuses stale draft hunks when the diff changed before submit.

Note: legacy current-hunk review uses `git diff` as the source of truth. Save the buffer first if you use `:ReviewLegacyCurrentHunk` and want cursor-to-hunk matching to stay accurate.

## Hunk Review Surface

Etabli installs Hunk from the official `hunkdiff` npm package documented at https://www.hunk.dev/. Use `<leader>ri`, `<leader>rh`, `<leader>rH`, `:ReviewInbox`, `:ReviewCurrentHunk`, or `:ReviewHunk` to open or reload `hunk diff --watch` for the current repository in a Neovim terminal tab. Pass explicit Hunk commands when needed, for example `:ReviewHunk diff` or `:ReviewHunk show HEAD~1`. This integration does not change the global Git pager.

When a live Hunk session exists, `:ReviewCurrentHunk` uses `hunk session navigate --repo <repo> --file <path> --new-line <line>` to move the Hunk viewport to the current buffer line. If no session exists, it opens Hunk first.

The full migration feasibility record is `docs/hunk-review-migration-feasibility.md`. Do not delete the persisted Etabli review state until the persistence decision in that document is resolved.

## Review inbox

- `<leader>ri` and `:ReviewInbox` open or reload Hunk for staged and unstaged hunks in the current repo.
- `:ReviewInbox [status|filter]` still accepts legacy arguments for command compatibility, but Hunk opens the full live diff because Hunk does not expose Etabli's local status filters.
- `:ReviewLegacyInbox [status|filter]` opens the old Telescope inbox with local status and attention filters.

The Hunk inbox is the scan-first review UI. It owns the live diff stream, file navigation, responsive split/stack layouts, inline notes, reload, and `--watch`. The legacy picker remains available only for durable local state features that Hunk does not yet cover: local statuses, draft transactions, stale markers, suggested-fix tracking, and persisted multiline range comments.

Legacy picker shortcuts:

- mark one or more entries with Telescope multi-select (`<Tab>` / `<S-Tab>`) before triggering a provider action if you want a batch prompt from the inbox
- default `<CR>` opens a diff tab for the selected live hunk, with the current file on the right when available
- `<C-a>` adds a review comment at the selected hunk start line
- `<C-s>` changes the selected hunk status
- `r` or `<C-g>` marks the selected hunk, or all marked hunks, as reviewed without accepting them
- `<C-y>` accepts the selected hunk, or all marked hunks
- `<C-c>` launches Claude directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-p>` launches Pi directly with the selected `revise` prompt, or one batch prompt if multiple entries are marked
- `<C-r>` refreshes the inbox after you changed the diff outside the picker
- `?` opens an overlay help panel for the legacy inbox shortcuts

Legacy attention filters:

- `:ReviewLegacyInbox attention` shows hunks that still need review action.
- `:ReviewLegacyInbox unresolved` shows hunks with unresolved review comments.
- `:ReviewLegacyInbox changed-since-review` shows hunks whose patch changed after they were marked reviewed.
- `:ReviewLegacyInbox reviewed:false` shows hunks that are still open.
- `:ReviewLegacyInbox reviewed:true` shows hunks already marked reviewed.
- `:ReviewLegacyInbox current-file` shows review items for the current buffer path.

The legacy inbox keeps a short-lived local cache for merged review items. This speeds up repeated opens during the same review pass without weakening review correctness: writes, deletes, directory changes, shell commands, focus changes, review status updates, and review notes all invalidate the cache.

By default, stale entries in `new`, `accepted`, or `ignore` are hidden from the legacy inbox to avoid noise after a revert or commit. Actionable stale entries such as `needs-rework` or `question` still stay visible by default. If you explicitly filter `:ReviewLegacyInbox new`, `:ReviewLegacyInbox accepted`, or `:ReviewLegacyInbox ignore`, those stale entries are still available.

## Agent Review

- `:ReviewClaudeBatch [status]` prepares one Claude prompt for every live hunk with that status
- `:ReviewPiBatch [status]` prepares one Pi prompt for every live hunk with that status
- `:ReviewClaudeReview [status|all|changed-only]` launches Claude with a Hunk HITL review prompt
- `:ReviewPiReview [status|all|changed-only]` launches Pi with a Hunk HITL review prompt
- `<leader>rbc` prepares the default Claude batch prompt for `needs-rework`
- `<leader>rbp` prepares the default Pi batch prompt for `needs-rework`
- `<leader>rvc` launches the Claude first-pass review for all live hunks
- `<leader>rvp` launches the Pi first-pass review for all live hunks

Batch commands still use the legacy local hunk model and are retained for status-scoped prompts. The first-pass review commands use Hunk when the CLI is available.

Review commands default to all live staged and unstaged hunks. Passing a status or `changed-only` narrows the Hunk prompt label for the agent, but Hunk itself remains the source of diff truth.

The Hunk review action is intentionally read-only. It asks the provider to inspect the live session with `hunk session review --repo <repo> --json`, add inline notes with `hunk session comment apply --stdin --json` or `comment add`, and end with `GO`, `GO WITH NOTES`, or `BLOCK`. It does not ask the provider to edit files.

Import agent review output back into local review state with `:ReviewIngestClaude [file]` or `:ReviewIngestPi [file]`. Without a file argument, the command reads the unnamed register. Imported findings must use the structured labels requested by the review prompt: `severity:`, `file:`, `line:` or `line_range:`, `issue:`, `impact:`, `review_comment:`, and optional `suggested_fix:`. Findings are anchored to live hunks before being stored; unmatched or duplicate findings are skipped. The Inbox shows provider counts such as `C:1` and `P:2`, inline annotations show compact agent markers, and `<leader>rg` or `:ReviewCompareAgents` compares Pi and Claude findings for the current hunk.

Suggested changes from imported `suggested_fix:` fields are preview-first. Use `<leader>rS` or `:ReviewSuggestionPreview` to open a markdown preview with the original finding, suggested fix, and a safety classification. Text-only suggestions are `preview-only`; diff suggestions are marked `safe-preview` only when all file markers target the current review file, otherwise they are `unsafe`. This flow does not auto-apply arbitrary agent patches. Use `:ReviewSuggestionStatus applied|rejected|resolved|open` to track the decision after manual review or application.

## Prompt dispatch behavior

Provider actions do three things:

1. build a deterministic prompt from the Hunk session or selected legacy hunk batch
2. copy it to the unnamed register and clipboard register when available
3. open a scratch preview and then launch `claude` or `pi` in a terminal tab when the CLI exists

This keeps the flow safe and explicit while removing the manual paste step: the prompt is still visible in the scratch preview and copied to registers, but the CLI also starts with the prompt already injected. Hunk review prompts tell the agent to inspect the live Hunk session and add inline Hunk comments. Provider prompts always launch the interactive CLI without a prompt argument and queue sanitized bracketed terminal paste input instead of using Claude `-p` / `--print` or leaking the full prompt through process arguments.

Provider CLIs are resolved from your environment, so the setup stays portable across machines instead of depending on a single hardcoded local path.

## Local state

Hunk is the default visible review UI. Local review state remains only for capabilities Hunk does not yet persist after session close: statuses, draft transactions, stale review markers, suggested-fix status, and exact multiline range anchors.

Review state is stored outside tracked project files under Neovim state:

- `stdpath("state")/etabli/review`

Entries are keyed by repo root, branch, diff scope, file path, hunk header, and patch hash. Review comments are stored with an id, target line range, body, resolved state, and timestamps.

## Smoke check

Run the isolated Neovim smoke check with:

```bash
tests/nvim-smoke.sh
```

The wrapper sets `XDG_STATE_HOME` to a temporary directory so review and Copilot state checks never write to the user's live Neovim state.
