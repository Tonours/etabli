# Herdr agent skill install

Skill source: `herdr/skills/herdr/SKILL.md` (regenerate with `herdr --skill`).

Only use when `HERDR_ENV=1` (agent inside a Herdr pane).

## Surfaces

| Harness | Path |
|---------|------|
| Claude Code | `~/.claude/skills/herdr` → etabli skill |
| Pi | `~/.pi/agent/skills/herdr` or `pi/skills/herdr` |
| Shared agents (Grok) | `~/.agents/skills/herdr` |
| Codex | `~/.codex/skills/herdr` |

## Link (laptop)

From etabli root:

```bash
SKILL_SRC="$PWD/herdr/skills/herdr"
ln -sfn "$SKILL_SRC" ~/.claude/skills/herdr
ln -sfn "$SKILL_SRC" ~/.agents/skills/herdr
ln -sfn "$SKILL_SRC" ~/.pi/agent/skills/herdr 2>/dev/null || true
mkdir -p ~/.codex/skills
ln -sfn "$SKILL_SRC" ~/.codex/skills/herdr
# Also track under pi/skills for install.sh if desired:
ln -sfn "$SKILL_SRC" pi/skills/herdr
```

## Mini

```bash
ssh macmini 'mkdir -p ~/.claude/skills ~/.codex/skills ~/.agents/skills
  # rsync skill tree first
'
rsync -az herdr/skills/herdr/ macmini:~/work/etabli-herdr/skills/herdr/
ssh macmini 'ln -sfn "$HOME/work/etabli-herdr/skills/herdr" ~/.claude/skills/herdr
ln -sfn "$HOME/work/etabli-herdr/skills/herdr" ~/.codex/skills/herdr
ln -sfn "$HOME/work/etabli-herdr/skills/herdr" ~/.agents/skills/herdr'
```
