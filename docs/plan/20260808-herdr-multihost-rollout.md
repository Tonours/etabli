# Implemented: Herdr multi-host rollout (laptop + macmini)

## Metadata
- Archived: 2026-08-08
- Source plan: Herdr multi-host rollout (macmini + local plugins + skills + layouts)
- Status: IMPLEMENTED
- Commit / branch: main (pending commit)

## Outcome
- Mac mini Herdr upgraded 0.6.6 → **0.8.0**; Mocha config synced; integrations claude/codex/opencode/grok current (pi absent on mini)
- Remote attach path proven: SSH bridge + client handshake to mini server (TUI needs real TTY)
- Plugins on laptop + mini: mirror, sessionizer, reviewr, file-viewer, memex, etabli.obvault
- Sessionizer layout for `~/work` + worktrees; repo-local `.sessionizer/config.toml` for etabli
- herdr skill linked into claude/codex/agents/pi surfaces (local + mini for claude/codex)
- Custom etabli.obvault plugin (obvault session/status + worktree hint)
- Docs: `herdr/docs/multihost.md`, `herdr/docs/skills.md`

## Context
- Mini GitHub SSH missing → plugins transferred via tar, linked local
- Codex hooks.json was broken symlink to Crucial etabli path → recreated real file
- Stale mini server sockets stopped before update

## Decisions
- Mirror over mobile notify as remote visibility path
- Sessionizer as declarative layout tool
- Phase 8 shipped (etabli.obvault) after 1–7 green

## Validation evidence
- `herdr --version` local+mini: 0.8.0
- `herdr config check`: ok both
- `herdr plugin list`: 6 plugins both hosts
- `herdr integration status` mini: claude/codex/opencode/grok current
- Remote: client handshake log + mini server "client connected"
- `tests/fix-links-smoke.sh`: ok
- `herdr plugin action invoke etabli.obvault.worktree-hint`: ok

## Residual risks
- Full interactive TUI remote attach not dogfooded in this agent shell
- Mirror may require herdr stream features — start daemon from Ghostty if autostart fails
- Mini has no `pi` binary; skill/integration skipped
- Mini plugin copies are local links, not github-managed; re-sync after laptop plugin updates

## Follow-ups
- From Ghostty: `herdr --remote macmini` once for TUI dogfood
- `herdr-mirror start` / focus workspace to populate `macmini: *` mirrors
- Optional: fix mini GitHub SSH for native `herdr plugin install`
- Optional: mini etabli full clone instead of rsync-only `etabli-herdr`
