# Herdr 0.9: laptop and Mac mini

## Roles and prerequisites

| Host | Role | Managed source |
|------|------|----------------|
| Laptop (Ghostty) | Interactive client, local Pi agents, native connection to Mini | Etabli checkout |
| Mac mini | Long-running agents and their host-local tools/vault | `~/work/etabli-herdr/` source bundle |

Use Herdr **0.9.0 or newer** on both hosts; matching versions simplify diagnosis.
Native connection negotiates compatibility. Upgrade deliberately on each host;
setup never upgrades Herdr or restarts a running server. Do not accept a server
replacement while jobs are running without first arranging their recovery.

Each host needs `herdr`, `python3`, `node`, `git`, `fzf`, `pi`, and `bun` for plugin
builds. Install Pi/Etabli and credentials on that host first. The Mini sync only
ships Herdr source and the canonical vault resolver; it does not provision Pi,
agent authentication, vault content, or the rest of Etabli. `gh`, `claude`,
`lazygit`, and `nvim` are needed for their corresponding optional shortcuts.

## Reproducible host setup

From the laptop's Etabli root:

```bash
herdr --version
bash herdr/scripts/setup.sh --install
bash herdr/scripts/setup.sh --check
./scripts/herdr-sync-mini
```

`--links` only manages configuration, Sessionizer and skill symlinks, without
network access or a Herdr binary. `install.sh` uses this mode; fix-links repairs
the configuration and Sessionizer links. Existing real files are backed up.
`--install` also installs the four tracked third-party plugins from commits in
`herdr/plugins.lock.tsv`, using Herdr's installer to run their builds on the
current host. Matching installations are reused. These are **source pins**;
vendor installers can still download release artifacts or use local tools.
Legacy local registrations of these four plugins are unlinked before installing
the pinned GitHub source; their old files and state remain available. If installation
fails, setup attempts to restore the former local registration and reports failure.
Other optional plugins are left alone. Local Obvault and Claude relaunch plugins
are linked, and official integrations are installed for available supported
agent CLIs (including Pi). Do not commit generated `pi/extensions/herdr-agent-state.ts`.

`--check` reads links, resolver availability, config validity, plugin registry
pins/enabled state, Sessionizer executable and integration status. It does not
install or repair anything. It is not a live end-to-end test of every plugin.

Mini sync validates its destination, copies managed source without deletion,
ships `workflow/runtime/obvault-topic-resolver.mjs`, runs host setup, reloads
configuration, and checks the result. Failure is reported as a nonzero exit.
It does not copy plugin checkout binaries from the laptop. Override the SSH
alias or destination with `HERDR_MINI_HOST` and `HERDR_MINI_TREE` if necessary.
A failed install can leave partial updates; fix the reported dependency and
rerun the same command. No running pane is restarted.

## Native machines and Mirror migration

After setup is verified on both hosts, run from the laptop:

```bash
herdr machine add macmini --label "Mac mini"
herdr machine list
```

This registers the Mini's default Herdr session over SSH. Keep the local and
remote servers running; switching machines selects where plugin actions and
commands execute. Client presentation stays local, while remote tools,
configuration, integrations, credentials and vaults must exist on the Mini.
Native connection does not synchronize those files.

Validate the native connection before retiring Mirror:

1. Switch to the Mini in Herdr and confirm machine labels identify its agents.
2. Open a test project through Sessionizer and confirm Pi is focused, with the
   agent pane taking 65 percent of the new split. Existing workspaces retain
   their layouts; use a new test workspace to check the default.
3. Run both Obvault actions and a plugin shortcut on the Mini. Confirm Pi state
   changes appear correctly and a completed test turn produces a notification.
4. Disconnect/reconnect the client and confirm the same Mini agent is still
   present. This checks connection recovery, not agent recovery after reboot.
5. Only after these pass, disable the old Mirror LaunchAgent and plugin through
   their existing management commands. Keep its configuration until the native
   route has been stable; setup does not remove or disable Mirror for you.

Direct attach remains a fallback from a real terminal:

```bash
herdr --remote macmini
# prefix+q detaches; the remote server keeps running panes
```

Legacy Mirror config is `~/.config/herdr-mirror/hosts.toml`; its LaunchAgent is
`~/Library/LaunchAgents/com.tonours.herdr-mirror.plist`. Avoid keeping two active
views of the same workspaces once migration is confirmed.

## Layout, vault and automation behavior

Both global and repository-local Sessionizer layouts start Pi and focus the
agent. All configured agent sidebar rows include the machine. System toasts
use a 3-second unfocused delay.

The Obvault plugin uses Etabli's central resolver: explicit `OBVAULT_ROOT` is
exclusive; work scope in `~/.etabli-scope` prefers `~/work/brain`, with the
resolver's Obvault fallback; personal/default scope uses Obvault. Both session
and status actions use the same resolved root. Missing vaults and CLI errors
are reported, not silently replaced with unrelated context.

Claude relaunch remains opt-in. On each host, enable it from the intended
Herdr session only after reading `herdr/plugins/claude-relaunch/README.md`.
Setup does not enable a new watcher; an already enabled watcher keeps its state.

| Plugin/action | Key |
|---------------|-----|
| Sessionizer projects / worktrees | `prefix+f` / `prefix+up` |
| Reviewr | `prefix+alt+r` |
| File viewer | `prefix+alt+v` |
| Memex | `prefix+alt+m` |
| Obvault context | `prefix+alt+o` |
| Claude relaunch manager | `prefix+alt+c` |

## SSH notes

`macmini` is the normal SSH alias; `macmini-shell` avoids the historical tmux
attach (`ETABLI_NO_TMUX=1`) for administration.

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

## Upstream references

- [Herdr 0.9.0 release](https://github.com/herdrdev/herdr/releases/tag/v0.9.0)
- [Connecting machines](https://herdr.dev/docs/connecting-machines/)
- [Configuration](https://herdr.dev/docs/configuration/)
- [Agent automation](https://herdr.dev/docs/agent-automation/)
- [Integrations](https://herdr.dev/docs/integrations/)
