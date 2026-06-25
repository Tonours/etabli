# Implemented: copy nvim and pi configs to local env, remove symlinks

## Metadata
- Archived: 2026-06-25
- Source plan: Copy nvim and pi configs to local env, remove symlinks
- Status: IMPLEMENTED
- Last revised (original): 2026-04-10
- Commit / branch: local-only operations, 0 repo files changed

## Outcome
- Replaced the `~/.config/nvim` symlink with a real copy of `etabli/nvim/`.
- Replaced the three `~/.pi/` symlinks (`settings.json`, `damage-control-rules.json`, `themes`) with real copies.
- Removed the orphan symlink `~/.pi/themes.bak.20260407`.
- Upgraded Neovim 0.12.0 -> 0.12.1 via brew.
- All primary and secondary checks passed (no symlinks remain, diffs identical, `nvim --version` = 0.12.1).

## Context
- `~/.config/nvim` and several `~/.pi/` entries were symlinks into the `etabli` repo; the goal was to decouple local configs from the repo by copying.
- Runtime files in `~/.pi/` (agent/, metrics/, npm/, patterns/, snapshots/, status/, projects.json) were explicitly left untouched.
- Review added a `pgrep nvim` guard before replacing the nvim config.

## Decisions
- 2026-04-10: Use direct sequential `rm` + `cp -r` per symlink rather than a script — each step independently verifiable, 0 repo diff.
