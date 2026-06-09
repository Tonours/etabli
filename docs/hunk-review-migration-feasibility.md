# Hunk Review Migration Feasibility

This document records the evidence for replacing Etabli's local Neovim review system with a Hunk-centered workflow.

## Decision

Current decision: **do not delete the existing local review state yet**.

Hunk is a strong replacement for the review surface: multi-file diff UI, live sessions, inline agent comments, session navigation, reload, `--watch`, JSON inspection, and agent skill control are confirmed. It is not yet a complete durable replacement for Etabli's current persisted review model because Hunk live comments did not survive closing and reopening the TUI during local smoke testing.

If "exclusive Hunk" means Hunk owns the visible review UI and AI HITL workflow, the migration is feasible with a thin persistence adapter. If it means no Etabli review persistence at all, the migration would drop currently supported behavior.

## Sources

- Hunk site: https://www.hunk.dev/
- Hunk repository: https://github.com/modem-dev/hunk
- Hunk README: https://github.com/modem-dev/hunk/blob/main/README.md
- Agent workflow guide: https://github.com/modem-dev/hunk/blob/main/docs/agent-workflows.md
- Hunk review skill: `hunk skill path`
- OpenTUI component guide: https://github.com/modem-dev/hunk/blob/main/docs/opentui-component.md
- Local CLI evidence: `hunk --help`, `hunk session --help`, `hunk session review --help`, `hunk session comment --help`

## Hunk Capabilities Confirmed

- `hunk diff`, `hunk diff --watch`, `hunk show`, `hunk patch`, `hunk pager`, `hunk difftool`
- Multi-file review stream with sidebar navigation
- Inline AI and agent annotations beside code
- Split, stack, and responsive layouts
- `hunk session list|get|context|review|navigate|reload`
- `hunk session comment add|apply|list|rm|clear`
- JSON review export through `hunk session review --json`
- Raw patch opt-in through `--include-patch`
- Live notes export through `--include-notes`
- Agent skill path through `hunk skill path`
- Agent batch comments through `comment apply --stdin`

## Local Smoke Evidence

Commands run against a temporary git repo with one changed file:

```bash
hunk diff --watch
hunk session list --json
hunk session get --repo "$(realpath <repo>)" --json
hunk session review --repo "$(realpath <repo>)" --json
hunk session comment add --repo "$(realpath <repo>)" --file demo.txt --new-line 2 --summary "Check changed beta" --rationale "Agent note with longer explanation." --author "Claude" --json
printf '%s\n' '{"comments":[{"filePath":"demo.txt","hunk":1,"summary":"Review added line","rationale":"Batch comment rationale","author":"Pi"}]}' | hunk session comment apply --repo "$(realpath <repo>)" --stdin --json
hunk session comment list --repo "$(realpath <repo>)" --type all
hunk session review --repo "$(realpath <repo>)" --include-notes --json
hunk session reload --repo "$(realpath <repo>)" -- diff
```

Observed:

- Hunk normalized macOS `/tmp` paths to `/private/tmp`, so automation must use canonical paths.
- `review --json` returned file and hunk structure without raw patch by default.
- `comment add` created a live inline agent note with `summary`, `rationale`, `author`, file path, side, and line.
- `comment apply --stdin` created batch inline agent notes.
- `review --include-notes --json` returned notes with `noteId`, `source`, `filePath`, `hunkIndex`, line range, body, author, timestamp, and `editable`.
- Notes survived `hunk session reload --repo <repo> -- diff`.
- Notes survived a file edit while the `--watch` session was live.
- Notes did **not** survive closing Hunk and opening a new Hunk session for the same repo.

## Capability Matrix

| Current Etabli capability | Hunk evidence | Decision |
| --- | --- | --- |
| Review Inbox | Hunk multi-file stream, sidebar, `hunk diff --watch`, `session review --json` | Confirmed replacement for visual review queue |
| Diff preview | Hunk review stream, split/stack layouts, patch export opt-in | Confirmed replacement |
| Inline comments | `session comment add`, `comment apply`, `comment list`, `--include-notes` | Confirmed for live sessions |
| Multiline comment body | `--summary` plus `--rationale`, note body includes both | Proxy-supported |
| Multiline line range comments | CLI targets hunk, old line, or new line, not an explicit selected range | Blocked for exact parity |
| Local review transactions | No draft transaction, submit verdict, approve/request-changes model in Hunk CLI | Blocked |
| Review statuses | No `new`, `needs-rework`, `question`, `accepted`, `ignore`, `reviewed` state in Hunk CLI | Blocked |
| Claude/Pi first-pass review | Hunk skill instructs agents to inspect session and add comments | Confirmed replacement direction |
| Ingest agent findings | Agent findings can become Hunk comments through `comment apply`; `--agent-context` exists for prewritten notes | Proxy-supported |
| Suggested fixes | Hunk comments can carry rationale, but no safety-classified suggested-fix preview/status workflow is documented | Blocked |
| Stale/changed tracking | `--watch` and `reload` update live session; no durable stale marker after close | Blocked for durable state |
| Cache/perf | Hunk owns review rendering and JSON model; Etabli cache can shrink if state is removed | Proxy-supported |
| HITL handoff | Hunk TUI plus `hunk session` lets AI inspect, navigate, and comment without editing code | Confirmed |
| Git pager integration | `hunk pager` is supported | Out of scope unless explicitly requested |

## Migration Options

### Option A: Hunk-only, ephemeral review

Delete Etabli's persisted review state and make Hunk the only review surface. This satisfies a strict reading of "exclusively Hunk" but loses durable comments, statuses, transactions, stale tracking, and suggested-fix state.

Decision needed before proceeding.

### Option B: Hunk UI plus thin Etabli persistence adapter

Hunk owns the visible review UI and agent HITL flow. Etabli keeps a minimal durable adapter that:

- stores comments/statuses that must survive Hunk close
- rehydrates comments into Hunk using `hunk session comment apply`
- exports Hunk notes back to durable state with `hunk session review --include-notes --json`
- launches Claude/Pi with the Hunk skill prompt
- removes the custom Telescope Inbox, diff previews, extmark annotation renderer, and scratch diff views once parity is proven

This is the robust path, but it is not "Hunk only" at the persistence layer.

### Option C: Upstream or wait for Hunk durable review state

Keep Etabli's current system until Hunk exposes durable review sessions or documented export/import semantics covering comments, statuses, and suggested fixes.

## Recommended Next Step

Use Option B unless the user explicitly accepts losing durable review metadata. The first implementation slice should:

1. Make `:ReviewInbox`, `<leader>ri`, and current-hunk preview commands open or reload Hunk instead of Telescope/scratch diff views. Implemented for the default path.
2. Change Claude/Pi review prompts to require `hunk skill path` and `hunk session review/comment` instead of pasting raw diff prompts. Implemented for first-pass review commands.
3. Keep Etabli state read-only or fallback-only until Hunk notes can be exported and rehydrated reliably. In progress: `ReviewAnnotate` writes directly to an active Hunk session, `:ReviewHunkSync pull` persists live Hunk notes into local state before close, and `:ReviewHunkSync push` rehydrates unresolved local comments/open findings back into Hunk with dedupe markers.
4. Add tests proving Hunk commands are the default review path and custom UI modules are no longer used when `hunk` is executable. Implemented in the Neovim review smoke test, including default keymap checks that leave local transaction/status/batch mappings disabled unless `vim.g.etabli_review_legacy_keymaps = 1`; legacy local commands are hidden unless `vim.g.etabli_review_legacy_commands = 1`; local inline annotations are also disabled unless explicitly enabled. The default command/keymap surface now routes through the smaller `config.review.hunk_flow` orchestrator, with local persistence isolated in `config.review.hunk_local_adapter`; `config.review` remains unloaded at startup unless legacy flags are enabled, and the default Hunk inbox opens without loading local review state/items/providers.

Do not delete `state.lua`, transactions, or suggestion state until the persistence decision is explicit.
