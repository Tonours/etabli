# Symlink layout

`scripts/deploy-agent-workflow --apply` (also run by `scripts/install.sh`) puts
these surfaces in your home. `--check` reports drift, `--check --fix` repairs
links, and `scripts/check-fix-symlinks.sh` is a shortcut for `--check`. Every
surface below comes from one manifest, `scripts/lib/surfaces.mjs` (ADR-0038).

## Claude links

Under `~/.claude/`, and the same set under `$CLAUDE_CONFIG_DIR` when it is set
and differs (the hook and skill checks read that one by default):

- `CLAUDE.md` -> `claude/claude-global.md`. The different name keeps a session
  that reads files under `claude/` from loading it again as nested memory.
- `workflow/` -> `workflow/`, and `review-rubric.md` -> `workflow/review-rubric.md`
- `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `skills/<name>/` -> `skills/<scope>/<name>/` or a vendored skill, for every
  active-scope row of `workflow/runtime/skill-surface.tsv`
- `agents/<name>.md` -> `claude/scopes/<scope>/agents/`
- `scripts/<name>` -> `claude/scopes/<scope>/scripts/`
- `hooks/<name>` -> `claude/hooks/`
- `statusline-command.sh` -> `claude/statusline-command.sh`
- `settings.workflow-hooks.json` -> `claude/settings.workflow-hooks.json`, a
  fragment `scripts/claude-hooks-merge` merges by hand (`claude/README.md` § Hooks)

Repo links under `commands/` are pruned: Claude commands are retired
(ADR-0037).

## Pi links

- `~/.pi/agent/AGENTS.md` -> `workflow/agent-rules.md`
- `~/.pi/agent/workflow/` and `~/.pi/workflow/` -> `workflow/`
- `~/.pi/agent/PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.pi/agent/models.json` -> `pi/models.json`
- `~/.pi/agent/extensions/` -> `pi/extensions/`
- `~/.pi/agent/agents/<name>.md` -> `pi/agents/`
- `~/.pi/agent/skills/<name>/` -> only the `pi_core=1` rows of
  `skill-surface.tsv`
- `~/.pi/agent/themes/<name>.json` and `~/.pi/themes/` -> `pi/themes/`
- `~/.pi/scripts/` -> `scripts/` (modules the Pi extensions import)
- `~/.pi/settings.json` -> `pi/settings.json`
- `pi/extensions/node_modules` (in the repo) -> `~/.pi/agent/npm/node_modules`,
  so the extensions resolve the packages Pi installs

## Shared links

`~/.local/bin/fix-links`, `deploy-workflow` and `security-audit-glm` ->
`scripts/`.

`agent` on your PATH stays Cursor's (`~/.local/bin/agent`): the installer
removes the `~/.grok/bin/agent` collision and Grok keeps `grok`
(`scripts/lib/prefer-cursor-agent.sh`).

## Copies and merges

These files hold local state, so deploy writes into them instead of linking:

- `~/.pi/agent/settings.json`: copied from `pi/agent/settings.json` when
  missing, then `scripts/lib/pi-agent-settings-sync.mjs` merges the tracked
  `packages` and `enabledModels` and replaces the `skills` key.
- `~/.claude/settings.json`: `scripts/lib/claude-settings-sync.mjs` copies only
  whitelisted keys from `claude/settings.skill-overrides.json` (`skillOverrides`,
  `permissions.defaultMode`, `attribution`, `autoMemoryEnabled`, the two skip
  prompts). Nothing is read back into the repo.

## Scopes

`~/.etabli-scope` holds `work` or `personal`, and `ETABLI_SCOPE` overrides it
for one run. You always get `shared` plus that scope; no file and no override
means `shared` alone. `claude/README.md` § Scopes has the rules.

## Not managed

- `~/.agents/`, `~/.codex/skills/` and `~/.config/devin/skills/` (ADR-0031):
  stale links there stay. Pi still reads `~/.agents/skills/`, so the Pi skill
  load check counts what it finds there.
- Editor, terminal and herdr config, herdr skill included: the
  [dotfiles](https://github.com/Tonours/dotfiles) repo owns them
  (`scripts/fix-links` there).
