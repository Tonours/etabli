# Symlink layout

Managed links installed by `scripts/deploy-agent-workflow` / `scripts/install.sh`; checked by `scripts/check-fix-symlinks.sh` (`deploy-agent-workflow --check`). Both read one desired state in `scripts/lib/surfaces.mjs` (ADR-0038).

- `~/.pi/agent/extensions/` -> `pi/extensions/`
- `~/.pi/scripts/` -> `scripts/` (canonical modules imported by calibrated Pi extensions)
- `~/.pi/workflow/` -> `workflow/` (canonical policies imported by calibrated Pi extensions)
- `~/.pi/agent/settings.json` stays local, bootstrapped from `pi/agent/settings.json`
- `~/.pi/agent/models.json` -> `pi/models.json`
- `~/.pi/agent/AGENTS.md` -> `workflow/agent-rules.md`
- `~/.pi/agent/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.pi/agent/workflow/` -> `workflow/`
- `~/.pi/settings.json` -> `pi/settings.json`
- `~/.pi/themes/` -> `pi/themes/`
- `~/.local/bin/fix-links` and `~/.local/bin/deploy-workflow` -> `scripts/`
- `~/.claude/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.claude/workflow/` -> `workflow/`
- `~/.claude/skills/<name>/` -> `skills/<scope>/<name>/` and vendored skills
  for every active-scope catalog row; `~/.pi/agent/skills/<name>/` gets only
  the `pi_core=1` rows. Claude commands are retired: repo `commands/*` links
  are pruned
- When `CLAUDE_CONFIG_DIR` is set and differs from `~/.claude`, deploy also
  maintains the same Claude surfaces (skills, agents, hooks, scripts,
  settings sync) there; `claude-hooks-merge`, `claude-hooks-check` and
  `claude-skill-load-check` read it by default. Live skills outside the tracked
  profile in that dir are reported by the load check, never removed; dangling
  managed links are replaced without a `.bak`
- `~/.agents/`, `~/.codex/skills/` and `~/.config/devin/skills/` are not
  managed (ADR-0031); stale links there are left alone. Pi still reads
  `~/.agents/skills/` natively, so the Pi skill load check counts what it finds there
- `~/.etabli-scope` selects `work` or `personal`; the active set is always
  `shared` plus that declared scope
- Env links (`nvim`, `ghostty`, `tmux`, `herdr` config/layouts, `herdr` skill) moved to the public `dotfiles` repo: see its `docs/symlink-layout.md` and `scripts/fix-links`. Etabli owns core workflow links only.
- `agent` on PATH is Cursor (`~/.local/bin/agent`); Grok is `grok` only — do not restore `~/.grok/bin/agent`
- do not create `~/.pi/extensions/`; it causes double-loading
- do not commit `pi/extensions/herdr-agent-state.ts` (installed/overwritten by `herdr integration install pi`)
- Mac mini Herdr deployment is owned by dotfiles `scripts/herdr-sync-mini` (see dotfiles `herdr/docs/multihost.md`).
