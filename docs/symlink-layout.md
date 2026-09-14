# Symlink layout

Managed links installed by `scripts/deploy-agent-workflow` / `scripts/install.sh`; checked by `scripts/check-fix-symlinks.sh`.

- `~/.pi/agent/extensions/` -> `pi/extensions/`
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
  `herdr/skills/herdr`; Devin also reads `~/.agents/skills/` natively, so
  `agents_visible` entries reach it through the shared surface. No other
  Devin harness state is tracked
- `~/.etabli-scope` selects `work` or `personal`; the active set is always
  `shared` plus that declared scope
- `~/.config/ghostty/config` -> `ghostty/config`
- `~/.config/herdr/config.toml` -> `herdr/config.toml`
- `~/.config/herdr/plugins/config/sessionizer/config.toml` -> `herdr/layouts/sessionizer.config.toml` (manual link; see `herdr/docs/multihost.md`)
- `herdr/skills/herdr` linked into `~/.claude/skills/herdr`, `~/.codex/skills/herdr`, `~/.agents/skills/herdr`, `~/.pi/agent/skills/herdr`
- `agent` on PATH is Cursor (`~/.local/bin/agent`); Grok is `grok` only — do not restore `~/.grok/bin/agent`
- do not create `~/.pi/extensions/`; it causes double-loading
- do not commit `pi/extensions/herdr-agent-state.ts` (installed/overwritten by `herdr integration install pi`)
- macmini deploy: rsync `herdr/` → `~/work/etabli-herdr/` (see `herdr/docs/multihost.md`)
