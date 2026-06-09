# UX/UI Code Flow Loop

Date: 2026-06-10

## Scope

Continuous improvement loop for the terminal-first development flow:

- Neovim review flow
- Hunk Inbox and session workflow
- Inline annotations and comment composer
- Claude/Pi first-pass review
- Diagnostics, floats, keymaps, prompts, validation scripts, and workflow docs

Hard constraints:

- Do not remove existing commands, keymaps, Hunk/Claude/Pi integrations,
  persistence, multiline comments, inline annotations, opt-in legacy behavior, or
  smoke tests.
- Do not add heavy dependencies.
- Do not push.

## Audit Grid

| Priority | Gap | Evidence | Impact | Surface | Complexity | Risk | Acceptance | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P1 | Default Hunk review flow lacks a dedicated discoverable help surface | `:ReviewInbox` now opens Hunk by default, but the existing `Review Inbox Help` text is owned by the legacy local inbox path in `config.review.init`; default keymaps only expose descriptions through which-key/command metadata | User can open the default review flow but has to remember commands for sync, comments, navigation, and Claude/Pi review | `nvim/init.lua`, `nvim/lua/config/keymaps.lua`, `nvim/lua/config/review/hunk_flow.lua` | Low | Low: additive command/keymap/help overlay only | Done: added `:ReviewHelp`, `<leader>r?`, and testable Hunk help content with the current default flow | Passed: `luac -p`, `tests/nvim-smoke.sh`, headless `:ReviewHelp` render |
| P3 | Legacy help text is long | `show_inbox_help()` lists many legacy commands | Low, because legacy commands are opt-in and not the default flow | `nvim/lua/config/review/init.lua` | Low | Medium: shortening could hide details for legacy users | Documented as not worth changing now | N/A |
| P3 | Statusline module is intentionally empty | `nvim/lua/config/statusline.lua` returns empty strings | Low, current setup favors minimal terminal-native surface | `nvim/lua/config/statusline.lua` | Medium | Medium: adding statusline state risks noise/perf | No change now | N/A |

## Loop Pass 1

Selected gap: P1 default Hunk review help.

Challenge:

- Value: high enough for P1 because discoverability is a core UX target and the
  default review flow is Hunk.
- Smaller alternative: only update docs. Rejected because the user needs help
  inside Neovim while reviewing.
- Performance impact: negligible; help text is created only on demand.
- Risk boundary: keep it additive and avoid loading the legacy `config.review`
  module from the lazy Hunk path.

Planned change:

- Done: added testable Hunk help lines in `config.review.hunk_flow`.
- Done: added `:ReviewHelp`.
- Done: added `<leader>r?`.
- Done: added smoke coverage for command/keymap/help text.

Evidence:

- Headless `:ReviewHelp` rendered `# Hunk Review Help`, default flow commands,
  Claude/Pi review commands, sync, navigation, and interactive terminal-paste
  note.
- `scripts/review_smoke.lua` asserts help content, headless render, command
  registration, and `<leader>r?` keymap description.
- The change is additive and does not load or rewrite the legacy review flow.

Validation:

- `git diff --check`: passed.
- `luac -p nvim/init.lua nvim/lua/config/keymaps.lua nvim/lua/config/review/hunk_flow.lua scripts/review_smoke.lua`: passed.
- `tests/nvim-smoke.sh`: passed.
- `tests/workflow-docs-smoke.sh`: passed.
- `scripts/profile-nvim-runtime.sh`: passed; review refresh warm remained
  `0.000ms` in this run.

## Audit Pass 2

Remaining P0/P1/P2 review:

- Navigation and discoverability: no remaining P0/P1/P2 after `:ReviewHelp`,
  `<leader>r?`, Inbox preview `Keys`, and command descriptions.
- Review flow: no remaining P0/P1/P2; Hunk is default, legacy remains opt-in,
  Claude/Pi are interactive and read-only for first-pass review.
- Inline comments: no remaining P0/P1/P2; compact/expanded thread behavior is
  smoke-tested.
- Narrow terminal: no remaining P0/P1/P2; adaptive picker layout is smoke-tested.
- Performance: no remaining P0/P1/P2; runtime profile is still green.

Decision: no P0/P1/P2 gap with gain greater than risk found in this pass.

## Audit Pass 3

Second consecutive no-gap pass:

- Rechecked the same surfaces against `docs/review-ui-ux-iteration.md`, current
  keymaps, Hunk help, picker preview, annotations, and validation output.
- P3 items remain intentionally deferred: long legacy help and empty statusline.
  Both are low value relative to risk because legacy is opt-in and the current
  statusline absence supports the restrained terminal surface.

Decision: no P0/P1/P2 rentable remains. Stop condition is satisfied after this
pass once commits are created and the worktree is clean.
