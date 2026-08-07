# Herdr multi-host (laptop + macmini)

## Roles

| Host | Role |
|------|------|
| Laptop (Ghostty) | Interactive client; local agents; `herdr --remote macmini` |
| Mac mini (`ssh macmini`) | Long-running agent herd; headless-friendly server |

## Versions

Both should run the same Herdr major/minor (target: `0.8.x`).

```bash
herdr --version
ssh macmini 'herdr --version'
```

Update:

```bash
herdr update
ssh macmini 'herdr update'
```

## Config

Source of truth: `etabli/herdr/config.toml`

- Laptop: `~/.config/herdr/config.toml` → symlink (install.sh)
- Mini: `~/work/etabli-herdr/config.toml` rsync'd from etabli, symlink from `~/.config/herdr/config.toml`

Sync after edits:

```bash
rsync -az --delete herdr/ macmini:~/work/etabli-herdr/
ssh macmini 'ln -sfn "$HOME/work/etabli-herdr/config.toml" ~/.config/herdr/config.toml && herdr server reload-config'
```

## Remote attach

```bash
# Ensure server on mini (first `herdr` or):
ssh macmini 'herdr status'   # start via `herdr` once if needed

# From laptop (real TTY / Ghostty):
herdr --remote macmini
# Detach: prefix+q (or close client); server keeps panes
```

OS notifications: `[ui.toast] delivery = "system"` in config.

## Plugins (laptop)

| Plugin | Key |
|--------|-----|
| sessionizer projects | `prefix+f` |
| sessionizer worktrees | `prefix+up` |
| reviewr | `prefix+alt+r` |
| file-viewer | `prefix+alt+v` |
| memex | `prefix+alt+m` |
| etabli obvault pack | `prefix+alt+o` |
| herdr-mirror | plugin actions `mirror.*` |

Install:

```bash
herdr plugin install nikok6/herdr-mirror --yes
herdr plugin install andrewchng/herdr-sessionizer --yes
herdr plugin install persiyanov/herdr-reviewr --yes
herdr plugin install smarzban/herdr-file-viewer --yes
herdr plugin install nicosuave/memex --yes
herdr plugin link "$(pwd)/herdr/plugins/etabli-obvault"
```

Sessionizer layout:

```bash
mkdir -p ~/.config/herdr/plugins/config/sessionizer
ln -sfn "$(pwd)/herdr/layouts/sessionizer.config.toml" \
  ~/.config/herdr/plugins/config/sessionizer/config.toml
```

## Skills

Tracked: `herdr/skills/herdr/SKILL.md` (from `herdr --skill`).

Linked into claude / pi / agents / codex skill trees by install notes in
`herdr/docs/skills.md`.

## SSH notes

- `macmini` — historical tmux attach via remote zshrc; prefer Herdr remote for agents
- `macmini-shell` — plain shell (`ETABLI_NO_TMUX=1`) for admin
