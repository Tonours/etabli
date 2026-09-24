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
- `~/.agents/PLAN_TEMPLATE.md` / `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.agents/workflow/` -> `workflow/`
- `~/.agents/skills/` receives catalog entries marked `agents_visible`; Grok
  discovers this shared surface
- `~/.codex/skills/` receives active-scope vendored skills; no other Codex
  harness state is tracked
- `~/.config/devin/skills/` receives active-scope vendored skills plus
  dotfiles `herdr/skills/herdr`; Devin also reads `~/.agents/skills/` natively, so
  `agents_visible` entries reach it through the shared surface. No other
  Devin harness state is tracked
- `~/.etabli-scope` selects `work` or `personal`; the active set is always
  `shared` plus that declared scope
- Env links (`nvim`, `ghostty`, `tmux`, `herdr` config/layouts, `herdr` skill) moved to the public `dotfiles` repo: see its `docs/symlink-layout.md` and `scripts/fix-links`. Etabli owns core workflow links only.
- `agent` on PATH is Cursor (`~/.local/bin/agent`); Grok is `grok` only — do not restore `~/.grok/bin/agent`
- do not create `~/.pi/extensions/`; it causes double-loading
- do not commit `pi/extensions/herdr-agent-state.ts` (installed/overwritten by `herdr integration install pi`)
- macmini deploy: `scripts/herdr-sync-mini` copies `herdr/` and the canonical vault resolver → `~/work/etabli-herdr/` (see `herdr/docs/multihost.md`)
