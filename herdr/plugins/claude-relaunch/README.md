# etabli.claude-relaunch

Herdr plugin that watches live Claude Code panes, detects usage-limit hits,
schedules an automatic relaunch ("cron") at the reset time, and exposes a
manager for those pending relaunches inside Herdr.

## How it works

- **Detection** — two paths funnel into the same scan:
  - a `pane.agent_status_changed` event hook probes the changed pane
    (near-real-time, only when it hosts a claude agent);
  - a background watcher (macOS LaunchAgent `com.etabli.herdr-claude-relaunch`,
    60 s interval; plain cron on Linux) scans all claude agents and fires due
    relaunches. Enable it once with the `enable` action.
- **Scheduling** — a banner like `usage limit reached … Until 5pm` creates one
  pending entry (state TSV under the plugin state dir) with a parsed
  `due_epoch`; unparseable reset times fall back to a 45-minute re-probe
  instead of guessing long.
- **Relaunch** — at due time: if the pane still hosts the claude agent, the
  plugin sends a continue prompt (`agent prompt`); if claude exited but the
  pane is alive, it runs `claude --continue` in that pane; if the pane is
  gone, the entry is dropped with a notification. A still-limited banner
  pushes the entry to the newly advertised reset time.
- **Manager** — the `crons` action (bound to `prefix+alt+c` in the etabli
  config) opens a popup listing pending relaunches with countdowns; keys:
  `r` refresh, `s` fire due now, `1-9` delete an entry, `w` toggle the
  watcher, `q` quit.

## Install

```sh
herdr plugin link <repo>/herdr/plugins/claude-relaunch
herdr plugin action invoke etabli.claude-relaunch.enable
```

Requires `jq` or `python3` for herdr JSON parsing, and `perl` for portable
reset-time parsing (fallback: 45-minute re-probe loop).

## State and logs

- `~/.local/state/herdr/plugins/etabli.claude-relaunch/crons` — pending entries
- `watcher.log` — every schedule/fire/drop decision
- `watcher.out` / `watcher.err` — LaunchAgent output

## Limitations

- Detection is screen-text based. A claude conversation that *quotes* a
  usage-limit banner near the bottom of the screen can false-positive; the
  consequence is one extra "continue" prompt, which is benign.
- Entries older than 12 h are expired; pane ids do not survive herdr
  restarts, so firing falls back to matching the stored claude session id
  before giving up.
- The watcher is per-machine and per-user; remote/mirror hosts are out of
  scope.

## Uninstall

```sh
herdr plugin action invoke etabli.claude-relaunch.disable
herdr plugin unlink etabli.claude-relaunch
```
