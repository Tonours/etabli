# Review UI/UX Iteration Audit

Date: 2026-06-09

## Goal

Iterate on the Neovim review UI until the current moodboard direction is fully
implemented or mapped to a justified terminal-native equivalent.

Source of truth:

- Research: `docs/review-ui-ux-research.md`
- Moodboard: local generated image from the research pass, intentionally not
  tracked with a user-specific filesystem path.

## Moodboard Checklist

| Item | Evidence target | Status |
| --- | --- | --- |
| Graphite/restrained terminal surface | Hunk paints a stable graphite review surface while Neovim-owned overlays use restrained highlight groups | Done: default Hunk launch uses `--theme custom --no-transparent-bg`; Etabli injects a graphite-derived Hunk theme with cyan review-note accents |
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

## 2026-06-10 Visual Alignment Pass

Comparison against the moodboard screenshots from the real Neovim run found
three visual drifts:

- Hunk was launched from Neovim with the generic `diff --watch` command instead
  of explicitly requesting the dense review layout.
- The Hunk comment composer used a large centered modal shape instead of the
  right-side thread rail shown in the moodboard.
- `:ReviewHelp` rendered as Markdown bullets in a centered overlay rather than
  as a compact TUI panel with status-first hierarchy and a key footer.

Changes made:

- Default Hunk launch is now
  `hunk diff --watch --mode auto --theme custom --no-wrap --line-numbers --agent-notes --no-transparent-bg`.
- Comment editors now use a right-side `Thread <file:range>` panel on wide
  terminals, with a `:w save | ZQ discard` footer and centered fallback on
  narrow terminals.
- Wide Hunk sessions now add a right-side Hunk context rail for `Thread`,
  `File`, and `Checks` context, sourced from `hunk session review --json`.
- Review help now renders as plain text in a right-side panel with `State`,
  `Flow`, `Layout`, `Keys`, `Agents`, `Sync`, and `Model` sections.

Current screenshot evidence:

- `/tmp/etabli-nvim-moodboard-screens/01-review-help.png`
- `/tmp/etabli-nvim-moodboard-screens/02-review-inbox-nvim.png`
- `/tmp/etabli-nvim-moodboard-screens/03-thread-composer.png`

Moodboard alignment status after this pass:

- Graphite/restrained terminal surface: Done.
- Thin coherent borders: Done.
- Dense diff surface: Done through explicit Hunk launch flags.
- Clear pane hierarchy: Done for Neovim-owned help/comment surfaces; Hunk owns
  the live diff pane.
- Inline GitHub-like thread composer: Done for line/range comment entry.
- Discoverable keyboard actions: Done through preview/help/footer text.
- Claude/Pi HITL behavior: Preserved, still interactive terminal paste.
- Performance budget: Done.

Validation for this pass:

- `git diff --check`: passed.
- `luac -p nvim/lua/config/review/hunk.lua nvim/lua/config/review/hunk_flow.lua nvim/lua/config/review/hunk_comment_editor.lua nvim/lua/config/review/hunk_local_adapter.lua nvim/lua/config/review/init.lua nvim/lua/config/review/util.lua scripts/review_smoke.lua scripts/review_hunk_lazy_smoke.lua scripts/etabli_doctor_smoke.lua`: passed.
- `tests/nvim-smoke.sh`: passed.
- `tests/workflow-docs-smoke.sh`: passed.
- `scripts/profile-nvim-runtime.sh`: passed, review refresh warm stayed at
  `0.000ms` in the local profile run.

## 2026-06-10 Inbox Chrome Iteration

Comparison after the first visual pass still showed one avoidable mismatch in
the Neovim-hosted Hunk inbox: the top chrome could include an empty `[No Name]`
buffer when launched from a fresh Neovim session, and the bottom statusline
showed a raw terminal buffer path instead of a review keybar.

Changes made:

- Hunk terminal windows now hide Neovim number/sign/fold/status columns.
- Hunk terminal windows now use a review keybar statusline:
  `q Quit | j/k Navigate | n/p Hunk | c Comment | a Agent | r Refresh | ? Help`.
- Launching Hunk from an untouched empty startup buffer now unlists only that
  empty buffer so the review surface starts on `hunk`, not `[No Name] | hunk`.

Current screenshot evidence:

- `/tmp/etabli-nvim-moodboard-screens/02-review-inbox-nvim.png`

Session probe result:

- Hunk stores live sessions with canonical repo roots. On macOS, the fixture
  path `/tmp/etabli-nvim-moodboard-review` resolves to
  `/private/tmp/etabli-nvim-moodboard-review`.
- `hunk session comment add --repo /private/tmp/etabli-nvim-moodboard-review`
  successfully added a live note to the Neovim-hosted Hunk session.
- Etabli already uses `M.realpath(context.repo)` for Hunk session commands, so
  the in-product annotation path is aligned with this requirement.

Current live-thread screenshot evidence:

- `/tmp/etabli-nvim-moodboard-screens/04-review-inbox-thread.png`

## 2026-06-10 Graphite Surface Iteration

Comparison against the moodboard showed that the transparent Hunk surface was
too dependent on the surrounding terminal and did not guarantee the graphite
panel depth visible in the reference.

Probe result:

- `hunk diff --watch --mode split --no-wrap --line-numbers --transparent-bg`
  emitted no stable background palette in the captured ANSI stream.
- `hunk diff --watch --mode split --no-wrap --line-numbers --no-transparent-bg`
  emitted stable graphite backgrounds such as `23;26;29`, `17;19;21`,
  `20;24;27`, and `24;28;32`, matching the moodboard's restrained terminal
  surface more closely.

Changes made:

- Default Hunk launch now uses `--theme custom --no-transparent-bg`.
- Default Hunk launch now also uses `--agent-notes` so agent review notes stay
  visible during triage instead of depending on the current focused comment.
- README, Neovim docs, cheatsheet, docs smoke, and review smoke assertions were
  updated to make the graphite-derived Hunk surface the explicit contract.
- Bufferline now labels Hunk terminal buffers as `etabli review`, so the top
  chrome reads as a review surface instead of a generic terminal buffer.

## 2026-06-10 Final Overlay Polish

Comparison against the moodboard after the graphite pass showed two remaining
Neovim-owned visual artifacts:

- `:ReviewHelp` launched from a fresh Neovim session still exposed a generic
  `[No Name]` buffer and line-number gutter behind the right-side panel.
- Floating review editors showed raw buffer names in the statusline instead of
  review actions.

Changes made:

- Empty startup buffers used as an overlay backdrop are now converted into a
  quiet `etabli review` surface, with number/sign/fold/status columns hidden.
- Review overlays now use a compact action statusline instead of leaking buffer
  names.
- Hunk and local comment composers now use a `:w Save | ZQ Discard` statusline
  in addition to the in-border footer.

Final screenshot evidence from a real Neovim/Hunk tmux run:

- `/tmp/etabli-nvim-moodboard-screens/09-review-help-final.png`
- `/tmp/etabli-nvim-moodboard-screens/10-review-inbox-thread-final.png`
- `/tmp/etabli-nvim-moodboard-screens/11-review-thread-composer-final.png`
- `/tmp/etabli-nvim-moodboard-screens/13-wide-agent-notes.png`
- `/tmp/etabli-nvim-moodboard-screens/15-right-rail-clean.png`

Alignment note:

- The Neovim-owned chrome, overlays, composer geometry, keybars, and default
  Hunk launch flags are aligned with the moodboard direction.
- Wide Neovim/Hunk sessions now show a right-side `Thread | File | Checks`
  context rail sourced from Hunk session state, matching the moodboard's
  persistent review context without reintroducing the legacy review UI.
- A wide multi-file Hunk run shows the Hunk-owned file/hunk rail beside the
  diff, with multiple agent notes visible inline through `--agent-notes`.
- Hunk's internal live agent-note styling is kept Hunk-native. Etabli injects an
  isolated custom Hunk theme under Neovim state so live notes use the moodboard
  cyan accent while preserving the graphite base and avoiding global Hunk config
  changes.

## 2026-06-10 Custom Hunk Theme Pass

Comparison against `/tmp/etabli-nvim-moodboard-screens/15-right-rail-clean.png`
found one remaining color mismatch: Hunk-owned inline agent-note borders still
used the built-in graphite purple, while the moodboard uses cyan evidence
markers. A real tmux run also showed that the Hunk diff could receive live
agent notes before the right context rail refreshed, leaving the rail with stale
`notes 0 / live 0` counts.

Changes made:

- Default Hunk launch now uses `--theme custom` instead of `--theme graphite`.
- Etabli writes a small Hunk config under `stdpath("state")/etabli/hunk-xdg`,
  not under the user global Hunk config and not inside the reviewed repository.
- The custom Hunk theme inherits `graphite` and overrides only accent and note
  colors, keeping the restrained terminal surface while aligning live note
  borders with the moodboard.
- The config write is idempotent and cached after first use, so frequent Hunk
  session checks do not keep touching disk.
- The Hunk terminal buffer now schedules a debounced context-rail refresh when
  terminal output changes, so inline notes and the rail converge without a
  polling loop.

Current screenshot evidence from the real Neovim/Hunk/tmux run:

- `/tmp/etabli-nvim-moodboard-screens/16-custom-hunk-theme.txt`
- `/tmp/etabli-nvim-moodboard-screens/16-custom-hunk-theme.ansi`
- `/tmp/etabli-nvim-moodboard-screens/16-custom-hunk-theme-viewport.png`
- `/tmp/etabli-nvim-moodboard-screens/16-custom-hunk-theme-overview.png`
- `/tmp/etabli-nvim-moodboard-screens/16-custom-hunk-theme-overview-tall.png`

Observed alignment:

- Hunk inline note borders emit ANSI `38;2;86;212;221`, matching the configured
  `#56d4dd` cyan accent.
- The rail refreshes to `notes 2 / live 2` after live agent notes appear.
- The right rail lists the selected thread, per-file note counts, and visible
  agent-note state while the inline notes remain anchored in the diff.

Validation for this pass:

- `git diff --check`: passed.
- `luac -p nvim/lua/config/review/hunk.lua nvim/lua/config/review/hunk_flow.lua nvim/lua/config/review/util.lua nvim/lua/config/review/hunk_comment_editor.lua nvim/lua/config/review/hunk_local_adapter.lua nvim/lua/config/review/init.lua nvim/lua/plugins/ui.lua scripts/review_smoke.lua scripts/review_hunk_lazy_smoke.lua scripts/etabli_doctor_smoke.lua`: passed.
- `tests/nvim-smoke.sh`: passed.
- `tests/workflow-docs-smoke.sh`: passed.
- `scripts/profile-nvim-runtime.sh`: passed, review refresh warm stayed at
  `0.000ms` in the local profile run.
