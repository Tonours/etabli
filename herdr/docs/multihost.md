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
| claude-relaunch | `prefix+alt+c` (pending relaunches) |
| herdr-mirror | plugin actions `mirror.*` |

Install:

```bash
herdr plugin install nikok6/herdr-mirror --yes
herdr plugin install andrewchng/herdr-sessionizer --yes
herdr plugin install persiyanov/herdr-reviewr --yes
herdr plugin install smarzban/herdr-file-viewer --yes
herdr plugin install nicosuave/memex --yes
herdr plugin link "$(pwd)/herdr/plugins/etabli-obvault"
herdr plugin link "$(pwd)/herdr/plugins/claude-relaunch"
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

### macmini: git SSH passphrase loop (fixed 2026-08-08)

**Symptom:** `git fetch` / `git@github.com` asks for the key passphrase in Herdr
panes or SSH sessions, but not in a local Terminal.app session on the mini.

**Cause:** macOS loads `SSH_AUTH_SOCK` only into the GUI login environment
(launchd `com.openssh.ssh-agent` + Keychain). Herdr panes and remote SSH shells
do not inherit it, so OpenSSH cannot see the already-loaded `id_rsa` and prompts.

**Fix (on the mini):** `.zprofile` reattaches to the GUI agent and runs
`ssh-add --apple-load-keychain` (block `etabli macOS ssh-agent (Keychain)`).
`Host github.com` uses `UseKeychain` / `AddKeysToAgent`. The key is stored in
the login Keychain so it reloads after unlock without re-prompting.

```bash
ssh-add -l
git ls-remote git@github.com:Tonours/etabli.git HEAD
```

### Sync laptop → mini

```bash
# from etabli root (also linked to ~/.local/bin by install.sh)
./scripts/herdr-sync-mini
```

Copies `herdr/` + plugin checkouts and re-links plugins/skills/config.

### Mirror (laptop)

- Config: `~/.config/herdr-mirror/hosts.toml` (`hosts.macmini`)
- LaunchAgent: `~/Library/LaunchAgents/com.tonours.herdr-mirror.plist`
- Manual start: `herdr-mirror-start`
- Expect workspace label `macmini: ~` in the local Herdr sidebar

### Remote attach (laptop Ghostty)

```bash
herdr --remote macmini
# detach: prefix+q — remote server keeps panes
```
