# Daily operational analysis

`etabli-durable-monitor.timer` runs at 08:00 Europe/Paris, including after a
missed invocation (`Persistent=true`). It collects local service state, bounded
run aggregates, backup freshness, current-invocation MCP startup messages and
the owned Chrome MCP package version. It never submits a model task, changes a
run, repairs a service, or sends reports to an external service.

Read `~/.local/state/etabli-durable-monitor/latest.md` for the latest report.
The proposals identify overdue runs, long queues, changed restart counters,
blocked-reason count changes, missing backups and unavailable MCP startup
proof. They are operational suggestions for human review, not a semantic
code-quality review or automatic implementation. Stored blocked runs are not
counted as new failures merely because another day passed.

Reports and state are private (directory0700, files0600). Only the last30
`records/YYYY-MM-DD.json` samples are authoritative. Day keys use Paris time;
collection timestamps use UTC. A same-day retry replaces that day's sample.
`latest.md` and `memory.md` are generated views; a crash can leave them stale,
and the next successful invocation regenerates them. `memory.md` is read as
prior context, never parsed as machine state or instructions. Invalid records
are named and excluded from comparisons. Interrupted temporary files are not
history; an excessive directory entry count stops collection for inspection.

API collection is GET-only on the owned Unix socket, capped at2MiB and5s.
Command output is capped at64KiB and5s; no raw prompts, transcripts, journal,
config, credentials or subscription endpoints are retained. If the unpaginated
run listing outgrows the bound, the report recommends a bounded metrics API.
MCP readiness means startup inventory was registered, not continuous backend
health. Rotated or oversized journal output is unavailable, never healthy.
Backup freshness checks file metadata, not restore integrity; the threshold
is36h. An increased restart counter reports automatic restarts even across invocation
changes; a lower counter or changed invocation without an increase is a reset. Quiet days do not establish code quality.

A successfully written report exits0, including degraded observations. A
status75 means overlap skipped: another invocation held the lock, so this one
wrote nothing. Other nonzero statuses mean collection/persistence failed, not
simply that the daemon was unhealthy. The unit has a120s overall timeout, no automatic retry,
and an OS file lock excludes overlapping runs. It has no external notification
channel; its journal names the report path. Inspect with:

```sh
systemctl --user start etabli-durable-monitor.service
systemctl --user status etabli-durable-monitor.service
systemctl --user list-timers etabli-durable-monitor.timer
cat ~/.local/state/etabli-durable-monitor/latest.md
```

Link the checked-in monitor service and timer into `~/.config/systemd/user/`,
reload units and enable the timer. They assume the checkout at `~/work/etabli`
and Node26 plus `flock` on the user manager's PATH. Disable with
`systemctl --user disable --now etabli-durable-monitor.timer`; this preserves
reports. Remove only the two installed monitor unit links to uninstall.

## Production MCP

Use `config.example.json` as an additive `mcpServers` object, preserving existing
private API/web/limits/notify configuration. The example uses `/usr/bin/node`
and `/usr/bin/chromium`; verify them on the deployment host. Install the pinned
Chrome package into an owned prefix, not an npx cache:

```sh
npm install --prefix "$HOME/.local/share/etabli-durable/mcp" --ignore-scripts --save-exact chrome-devtools-mcp@1.7.0
```

The configured isolated headless browser does not use personal browser profiles.
Both telemetry and CrUX options are disabled, with explicit environment opt-outs
for usage statistics and update checks. No package download occurs at daemon
startup. The vault server retains its existing personal root and state directory.
These trusted MCP tools can still read/write resources allowed by their native
tools; this is not a sandbox.

Before activating, test the exact config through the native adapter in a bounded
transient user-systemd unit, using read-only vault and blank browser operations.
The executed preflight command was:

```sh
systemd-run --user --wait --pipe --collect --unit=etabli-operations-preflight -p WorkingDirectory=/home/tonours/work/etabli -p UMask=0077 -p RuntimeMaxSec=90 -p TimeoutStopSec=5 -p KillMode=control-group /usr/bin/node /home/tonours/work/etabli-durable-tui/durable/__tests__/fixtures/operations-mcp.ts /tmp/etabli-durable-operations/proposed-mcp.json /tmp/etabli-durable-operations/mcp-preflight.json
```

For a later deployment, substitute the reviewed checkout, owned0600 exact MCP
config and private proof destination paths; retain the unit name and bounds.
The fixture requires that unit name, writes a0600 proof, and reads at most128B
from the fixed vault path `kb/harness-engineering-integration-points.md`.
If that note moves, the preflight fails closed; it does not pick another note.

After restarting the idle daemon, require `ready` for both servers under its new
`_SYSTEMD_INVOCATION_ID`. A separate callable preflight and daemon startup readiness
are distinct evidence; neither claims an internal production model tool call.
Missing invocation journal evidence blocks activation. Preserve the old0600
config and a separate immutable SQLite backup outside daily backup retention;
restore the config and restart if either server skips. Avoid restarting with an
active run or an imminent schedule. Keep Serve, VAPID and subscriptions intact.
