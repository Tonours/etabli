# Symlink layout

`scripts/deploy-agent-workflow --apply` puts these surfaces in your home, and
`scripts/install.sh` runs it for you. Every surface below comes from one
manifest, `scripts/lib/surfaces.mjs` (ADR-0038).

## Basic usage

```bash
scripts/deploy-agent-workflow              # dry run, the default: prints the drift
scripts/deploy-agent-workflow --apply      # links, prunes, then syncs settings
scripts/deploy-agent-workflow --check      # reports drift and skill-load failures, skips the settings sync
scripts/deploy-agent-workflow --check --fix
scripts/check-fix-symlinks.sh              # shortcut for --check, takes --fix
```

After an `--apply` on your live home, the deploy runs
`scripts/claude-skill-load-check` and fails when it does. Under
`scripts/install.sh` a failed check only warns. On a live home `--check` runs
both skill-load checks; the Pi one launches `pi` once, which applies Pi's own
startup migrations like any Pi session. `ETABLI_SKIP_LIVE_CHECKS=1`
treats the home as non-live and skips it; `ETABLI_SKIP_SKILL_LOAD_CHECKS=1`
skips only the skill-load checks of `--check`, for link-only test fixtures.

A foreign file sitting on a managed name is moved aside to
`<name>.bak.<stamp>` (under `skills.bak/` for a skill), never deleted. A
foreign symlink is moved aside the same way, except under `scripts/install.sh`,
which replaces it. Settings
files get a timestamped copy before each write, and the newest 5 of those are
kept.

## Claude links

Under `~/.claude/`. When `$CLAUDE_CONFIG_DIR` names an existing directory other
than `~/.claude`, either under your home or anywhere when `HOME` is your login
home, and the deploy targets the live home, the Claude links and the Claude settings
sync go there too. The hook and skill checks read it by default.

- `CLAUDE.md` -> `claude/claude-global.md`. The different name keeps a session
  that reads files under `claude/` from loading it again as nested memory.
- `workflow/` -> `workflow/`, and `review-rubric.md` -> `workflow/review-rubric.md`
- `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `skills/<name>/` -> `skills/<scope>/<name>/` or a vendored skill, for every
  active-scope row of `workflow/runtime/skill-surface.tsv`. Under the `work`
  scope, `adr` is withheld (`SHADOWS` in `scripts/lib/surfaces.mjs`).
- `agents/<name>.md` -> `claude/scopes/<scope>/agents/*.md`
- `scripts/<name>` -> `claude/scopes/<scope>/scripts/`
- `hooks/<name>` -> `claude/hooks/*.mjs` and `*.sh`
- `statusline-command.sh` -> `claude/statusline-command.sh`
- `settings.workflow-hooks.json` -> `claude/settings.workflow-hooks.json`, a
  fragment you merge with `scripts/claude-hooks-merge`
  ([`claude/README.md`](../claude/README.md) § Hooks)

Repo links under `commands/` are pruned, since Claude commands are retired
(ADR-0037). So are links to hooks, agents, scripts and skills the repo no
longer ships.

## Pi links

- `~/.pi/agent/AGENTS.md` -> `workflow/agent-rules.md`
- `~/.pi/agent/workflow/` and `~/.pi/workflow/` -> `workflow/`
- `~/.pi/agent/PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.pi/agent/models.json` -> `pi/models.json`
- `~/.pi/agent/extensions/` -> `pi/extensions/`
- `~/.pi/agent/agents/<name>.md` -> `pi/agents/*.md`
- `~/.pi/agent/skills/<name>/` -> only the `pi_core=1` rows of
  `skill-surface.tsv`
- `~/.pi/agent/themes/<name>.json` and `~/.pi/themes/` -> `pi/themes/`
- `~/.pi/scripts/` -> `scripts/` (modules the Pi extensions import)
- `~/.pi/settings.json` -> `pi/settings.json`
- `pi/extensions/node_modules` (in the repo) -> `~/.pi/agent/npm/node_modules`,
  so the extensions resolve the packages Pi installs. A non-live home skips it.

The deploy removes the retired `~/.pi/agent/subagents.json` link and requires
`~/.pi/extensions` to be absent: that path makes Pi load every extension twice.

## Codex links

Codex is a managed runtime again (ADR-0043). Pi reads none of these paths.

- `~/.codex/AGENTS.md` -> `codex/AGENTS.md`, the adapter. Codex has no
  import, so it tells the model to read `~/.codex/workflow/agent-rules.md`.
- `~/.codex/workflow/` -> `workflow/`
- `~/.codex/PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md` -> repo root templates
- `~/.codex/skills/<name>/` -> the same rows as the Claude skills, `adr`
  withheld under `work` too. Personal folders and foreign links on other
  names stay.

When `~/.codex` or `~/.codex/skills` overlaps, physically and in either
direction, a root Pi or Claude reads (`~/.pi`, `~/.agents`, their skill
folders, every Claude config dir this deploy serves) or an entry those skill
folders list, the deploy skips every Codex link and reports it unresolved.
A link you make deeper into `~/.codex/skills` (a nested folder, a single
`SKILL.md`, a Pi settings skill path) is not checked; the folder it reaches
moves to `~/.codex/skills.bak/` and Pi then loads the catalog skill.

## Shared links

`~/.local/bin/fix-links`, `deploy-workflow` and `security-audit-glm` ->
`scripts/`.

`agent` on your PATH stays Cursor's (`~/.local/bin/agent`). The installer
removes the `~/.grok/bin/agent` collision, and Grok keeps `grok`
(`scripts/lib/prefer-cursor-agent.sh`).

## Copies and merges

These files hold local state, so the deploy writes into them instead of
linking them. `--apply` runs both syncs; `--check` skips them.

- `~/.pi/agent/settings.json`: copied from `pi/agent/settings.json` when
  missing. Then `scripts/lib/pi-agent-settings-sync.mjs` merges the tracked
  `packages` and `enabledModels`, drops legacy packages and retired models,
  and replaces the `skills` key.
- `~/.claude/settings.json`: `scripts/lib/claude-settings-sync.mjs` merges
  `skillOverrides` from `claude/settings.skill-overrides.json`, where the
  tracked entries win, and copies the other keys the fragment carries,
  `attribution`, `autoMemoryEnabled`, `promptSuggestionEnabled`,
  `awaySummaryEnabled` and optional
  `env.CLAUDE_CODE_SUBAGENT_MODEL` support (not activated in the shared fragment).
  The PATH check does not certify SDK/IDE runtimes; other local env keys are preserved. The
  whitelist also admits `permissions.defaultMode` and the two skip prompts, and
  refuses any other key. Nothing is read back into the repo.
  Managed suggestion/away-recap defaults are false and overwrite local toggles
  on deploy; their native environment overrides are preserved. Compaction,
  model, effort and permission defaults are not changed by these two keys.

## Scopes

`~/.etabli-scope` holds `work` or `personal`, and `ETABLI_SCOPE` overrides it
for one run. You always get `shared` plus that scope, and no file and no
override means `shared` alone. [`claude/README.md`](../claude/README.md) §
Scopes has the rules.

## Not managed

- `~/.agents/` and `~/.config/devin/skills/` (ADR-0031):
  stale links there stay. Pi still reads `~/.agents/skills/`, so the Pi skill
  load check counts what it finds there.
- Editor, terminal and herdr config, herdr skill included: the
  [dotfiles](https://github.com/Tonours/dotfiles) repo owns them
  (`scripts/fix-links` there).

## What's next

[`claude/README.md`](../claude/README.md) covers what the Claude links carry:
hooks, agents and skill governance.
