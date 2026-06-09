# Review UI/UX Iteration Audit

Date: 2026-06-09

## Goal

Iterate on the Neovim review UI until the current moodboard direction is fully
implemented or mapped to a justified terminal-native equivalent.

Source of truth:

- Research: `docs/review-ui-ux-research.md`
- Moodboard:
  `/Users/tonours/.codex/generated_images/019e99f1-c213-7690-9cbf-4f7858403eed/ig_0327c6b7cc7a4723016a28880e3d308191a5b5f84b486d34ce.png`

## Moodboard Checklist

| Item | Evidence target | Status |
| --- | --- | --- |
| Graphite/restrained terminal surface | Neovim keeps terminal/theme ownership and uses restrained highlight groups, not saturated custom surfaces | Done: terminal-native theme ownership in `nvim/init.lua`; no decorative review colors added |
| Thin coherent borders | All review/diagnostic floating surfaces use `single` borders | Done: `nvim/lua/config/options.lua`, `nvim/lua/config/review/util.lua`, `providers.lua`, `hunk_comment_editor.lua`, `hunk_local_adapter.lua`, `init.lua` |
| Dense hunk list | Review inbox entries fit attention, scope, status, activity, reviewed state, and location on one row | Done: `nvim/lua/config/review/picker.lua` |
| Clear pane hierarchy | Inbox has a list and preview, preview puts state/activity/comments/agents before diff | Done: `picker.preview_lines()` headless rendering |
| Adaptive narrow-terminal layout | Inbox switches away from wide horizontal assumptions on narrow columns | Done: `picker.layout_for_columns(90)` returns `vertical`; `picker.layout_for_columns(160)` returns `horizontal` |
| Discoverable keyboard actions | Common actions are visible without leaving the review context | Done: preview renders `Keys      Enter diff | Ctrl-A comment | Ctrl-S status | Ctrl-C Claude | Ctrl-P Pi | ? help` |
| Inline GitHub-like review threads | Compact by default, expanded on current thread, range-aware, no unlimited virtual-line rendering | Done: `nvim/lua/config/review/annotations.lua`, protected by `scripts/review_smoke.lua` |
| Claude/Pi as evidence tags | Agent findings show provider/severity/status/suggestion without implying auto-acceptance | Done: `picker.preview_lines()` renders `provider/severity ... [status] +suggestion` |
| Persistence/sync feedback | Hunk sync and comment save paths report local/Hunk persistence state | Done: `hunk_flow.lua`, `hunk_local_adapter.lua`, `init.lua`; smoke tests cover persistence |
| Useful empty/error states | Missing Hunk/Telescope/repo/CLI states produce actionable terminal messages | Done: local messages inspected in `hunk.lua`, `hunk_flow.lua`, `hunk_local_adapter.lua`, `picker.lua`, `providers.lua` |
| No decorative dashboards | No marketing cards, no full-dashboard rewrite, no decorative animation | Done: implementation remains Telescope/Neovim-native |
| No modal-first drift | Comment editor is a focused acwrite buffer with save/discard semantics; diff opens in real buffers | Done: existing composer/diff flow preserved |
| No layout shift | Fixed-width picker columns and capped preview sections/diff lines | Done: `picker.lua` caps text, sections, and diff preview |
| No notable performance cost | Smoke and runtime profile remain green after UI changes | Done: `tests/nvim-smoke.sh`, `tests/workflow-docs-smoke.sh`, and `scripts/profile-nvim-runtime.sh` passed |

## Iteration Plan

1. Done: add a small adaptive picker layout helper so narrow terminals use a
   vertical preview instead of a cramped horizontal split.
2. Done: add an explicit `Keys` line to the preview body so action discovery
   survives preview screenshots/headless rendering and mirrors the moodboard
   footer.
3. Done: add smoke assertions for the adaptive layout and preview keys.
4. Done: re-run syntax, whitespace, smoke tests, headless render, and runtime
   profile.

## Final Evidence

- `git diff --check`: passed.
- `luac -p nvim/lua/config/review/picker.lua scripts/review_smoke.lua`: passed.
- `tests/nvim-smoke.sh`: passed.
- `tests/workflow-docs-smoke.sh`: passed.
- `scripts/profile-nvim-runtime.sh`: passed; review refresh warm stayed at
  `0.000ms` in the local profile run.
- Headless render showed the review preview with `State`, `Activity`, `Keys`,
  `Draft comments`, `Open comments`, `Agent findings`, and `Diff`.
- Headless layout check showed `layout narrow=vertical wide=horizontal`.

## Completion Rule

The goal is complete only when every checklist item is `Done` with current
evidence, validations pass, and the work is committed atomically without push.
