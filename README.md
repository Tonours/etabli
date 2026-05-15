# Etabli

Personal dev environment for AI-assisted workflows across Neovim, Claude Code, Pi Coding Agent, Ghostty, and tmux.

The repo is the source of truth for tracked config. `scripts/install.sh` links or bootstraps local files into the expected tool locations.

## Quick start

```bash
git clone https://github.com/Tonours/etabli.git
cd etabli
./scripts/install.sh
```

## Repo map

- `nvim/` - Neovim config
- `ghostty/` - Ghostty terminal config
- `tmux.conf` - tmux config
- `pi/` - Pi config, extensions, skills, themes
- `claude/` - Claude Code commands and local instructions
- `workflow/` - canonical workflow contract and templates
- `docs/` - focused user docs
- `scripts/` - installer and maintenance scripts

## Workflow

Canonical contract: `workflow/spec.md`.

Default loop:

```text
learn -> plan -> implement -> review -> validate
```

Use `PLAN.md` as the only execution artifact. Implement only from `Status: READY`.

## Useful commands

```bash
fix-links check
fix-links
bun test pi/extensions/__tests__/
```

Pi:

```text
/skill:plan-loop <task>
/skill:plan-implement <task>
/skill:implement
/skill:review
```

Claude:

```text
/plan-loop
/plan-implement
/implement
/review
```

## Config notes

- `pi/agent/settings.json` is a tracked bootstrap/default; live `~/.pi/agent/settings.json` stays local.
- `pi/models.json` and `pi/settings.json` are linked into `~/.pi/`.
- `ghostty/config` is linked to `~/.config/ghostty/config`.
- secrets and auth files stay local and untracked.

## References

- `workflow/spec.md` - workflow contract
- `workflow/review-rubric.md` - review output and priorities
- `PLAN_TEMPLATE.md` - default lightweight plan
- `PLAN_TEMPLATE_FULL.md` - full plan for risky work
- `docs/pi-cheatsheet.md` - Pi usage reminders
- `nvim/README.md` - Neovim notes
- `claude/README.md` - Claude installed surface
