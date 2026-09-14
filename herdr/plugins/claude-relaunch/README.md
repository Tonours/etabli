# etabli.claude-relaunch

Opt-in, bounded automatic continuation of a Claude Code session after a usage
limit. Setup links this plugin but does not enable its background watcher.

## Behavior

A `pane.agent_status_changed` hook and an optional 60-second watcher scan Claude
agents. A detected limit banner captures the native Claude session identity and
reset deadline once. Repeated scans of the same banner never roll an expired
clock time into tomorrow. Unparseable times use a 45-minute initial re-probe.

At the deadline, the plugin finds the original native session, including if it
moved to a different pane, and requires `idle` or `done`. Working, blocked,
unknown, missing or ambiguous sessions are paused for inspection. It never
runs `claude --continue` in a shell. A changed, parseable reset banner can defer
the attempt; an unchanged expired banner does not defer it again.

Server/screen failures and changed future reset times consume a maximum of
three retries. Entries older than 12 hours are paused, including longer weekly
limits. The plugin persists a pause before sending one continuation prompt;
success, timeout or process interruption cannot automatically rearm that entry.
A timeout may mean input was submitted, so it must be inspected manually.
Legacy records without the required identity/retry fields also pause safely.

Paused entries remain visible and suppress new scheduling for that session.
Use the manager to inspect the session and delete its entry to explicitly rearm
future detection. Deleting an entry while a limit banner remains allows a new
schedule on the next scan.

## Enable on the intended host/session

```sh
herdr plugin link <repo>/herdr/plugins/claude-relaunch
herdr plugin action invoke etabli.claude-relaunch.enable
```

Enable from inside the target Herdr session so `HERDR_SOCKET_PATH` is available.
The watcher saves that socket and rejects a conflicting session socket. This
implementation supports one watched Herdr session per user per host; enable
separately on the laptop and Mini. Named sessions are not multiplexed.
If changing servers/sockets, disable the old watcher, inspect/clear its entries,
and remove its saved `socket` file before enabling in the new session.

Requires Bash, Herdr, `jq` or `python3` for JSON, and `perl` for clock parsing.
macOS LaunchAgent generation additionally requires `python3`. Linux uses cron.
The watcher uses its recorded Herdr binary and socket, not whichever session a
later terminal happens to select.

## Manager and state

`prefix+alt+c` opens pending and paused entries. Keys: `r` refresh, `s` process
due entries, `1-9` delete, `w` toggle watcher, `q` quit. Processing due entries
does not override identity, status, deadline or pause checks.

State defaults to `~/.local/state/herdr/plugins/etabli.claude-relaunch/`:

- `crons`: pipe-separated records containing deadline, pane, agent, native
  session, cwd, creation epoch, note, retry count and captured reset text.
- `socket`: bound server socket.
- `watcher.log`: decisions; `watcher.out` / `watcher.err`: LaunchAgent output.

## Limits and on-device checks

Screen detection is heuristic: quoted limit text can trigger a schedule and
later a continuation. Enable only where that automation is desired. Identity
and state are checked again immediately before input, but Herdr's prompt API
is not an atomic compare-and-send operation; a session can change in that gap.

The smoke tests simulate clock changes, pane reuse/moves, blocked and working
agents, failures, retry caps and legacy state. Validate launchd/cron activation,
correct socket targeting and a disposable Claude session on the actual host
before relying on unattended continuation. Reboot recovery of agent processes
is outside this plugin's scope.

## Disable/unlink

```sh
herdr plugin action invoke etabli.claude-relaunch.disable
herdr plugin unlink etabli.claude-relaunch
```

Disable removes the scheduler, retaining entries and socket binding for review.
