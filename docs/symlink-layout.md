# Symlink layout

Managed links installed by `scripts/deploy-agent-workflow` / `scripts/install.sh`; checked by `scripts/check-fix-symlinks.sh`.

- `~/.pi/agent/extensions/` -> `pi/extensions/`
- `~/.pi/scripts/` -> `scripts/` (canonical modules imported by calibrated Pi extensions)
- `~/.pi/workflow/` -> `workflow/` (canonical policies imported by calibrated Pi extensions)
- `~/.pi/agent/settings.json` stays local, bootstrapped from `pi/agent/settings.json`
- `~/.pi/agent/models.json` -> `pi/models.json`
- `~/.pi/agent/AGENTS.md` -> `pi/AGENTS.md`
- `~/.pi/agent/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.pi/agent/workflow/` -> `workflow/`
- `~/.pi/settings.json` -> `pi/settings.json`
- `~/.pi/themes/` -> `pi/themes/`
- `~/.claude/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.claude/workflow/` -> `workflow/`
- When `CLAUDE_CONFIG_DIR` is set and differs from `~/.claude`, deploy also
  maintains the same Claude surfaces (commands, skills, agents, hooks, scripts,
  settings sync) there; `claude-hooks-merge`, `claude-hooks-check` and
  `claude-skill-load-check` read it by default. Live skills outside the tracked
  profile in that dir are reported by the load check, never removed; dangling
  managed links are replaced without a `.bak`
- the Claude plugin marketplace `etabli-local` -> `claude/mods`, with
  `etabli@etabli-local` installed at user scope and read from the checkout
  (`docs/claude-etabli-mod.md`)
- `~/.agents/`, `~/.codex/skills/` and `~/.config/devin/skills/` are retired
  (ADR-0031): deploy and fix-links remove this checkout's links there and leave
  real directories and foreign links alone. Pi still reads `~/.agents/skills/`
  natively, so the Pi skill load check counts what it finds there
- `~/.etabli-scope` selects `work` or `personal`; the active set is always
  `shared` plus that declared scope
- Env links (`nvim`, `ghostty`, `tmux`, `herdr` config/layouts, `herdr` skill) moved to the public `dotfiles` repo: see its `docs/symlink-layout.md` and `scripts/fix-links`. Etabli owns core workflow links only.
- `agent` on PATH is Cursor (`~/.local/bin/agent`); Grok is `grok` only — do not restore `~/.grok/bin/agent`
- do not create `~/.pi/extensions/`; it causes double-loading
- do not commit `pi/extensions/herdr-agent-state.ts` (installed/overwritten by `herdr integration install pi`)
- Mac mini Herdr deployment is owned by dotfiles `scripts/herdr-sync-mini` (see dotfiles `herdr/docs/multihost.md`).
