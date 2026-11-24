# Symlink layout

`scripts/deploy-agent-workflow --apply` puts these surfaces in your home, and
`scripts/install.sh` runs it for you. Every surface below comes from one
manifest, `scripts/lib/surfaces.mjs` (ADR-0038).

## Basic usage

```bash
scripts/deploy-agent-workflow              # dry run, the default: prints the drift
scripts/deploy-agent-workflow --apply      # links, prunes, then syncs settings
scripts/deploy-agent-workflow --check      # reports link/settings drift and skill-load failures without writing settings
scripts/deploy-agent-workflow --check --fix
scripts/check-fix-symlinks.sh              # shortcut for --check, takes --fix
```

After an `--apply` on your live home, the deploy runs
`scripts/claude-skill-load-check` and fails when it does. Under
`scripts/install.sh` a failed check only warns. On a live home `--check` runs
both skill-load checks; the Pi one launches `pi` once, which applies Pi's own
startup migrations like any Pi session. `ETABLI_SKIP_LIVE_CHECKS=1`
treats the home as non-live and skips it; `ETABLI_SKIP_SKILL_LOAD_CHECKS=1`
skips only the skill-load and settings-drift checks of `--check`, for
link-only test fixtures.

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
linking them. `--apply` runs both syncs; `--check` checks tracked-settings
drift for both Pi and Claude read-only without writing or creating backups.

- `~/.pi/agent/settings.json`: copied from `pi/agent/settings.json` when
  missing (and detached from any symlink before `--apply`; `--check` flags a
  symlink as drift without detaching it). Then
  `scripts/lib/pi-agent-settings-sync.mjs` merges the tracked `packages`,
  `enabledModels` and additive `defaultTools` (`["+codemode"]`, appended to
  unset, delta, or non-empty plain allowlists while preserving explicit
  `-codemode` opt-outs, existing `codemode` entries, and explicit empty `[]`
  allowlists), drops legacy packages (including `npm:pi-mcp-adapter`, stripping
  stale `-builtin:mcp` from `extensions` in that same migration run while
  preserving deliberate `pi config` opt-outs afterwards) and retired models,
  and replaces the `skills` key.
- `~/.claude/settings.json`: `scripts/lib/claude-settings-sync.mjs` merges
  `skillOverrides` from `claude/settings.skill-overrides.json`, where the
  tracked entries win, and copies the other keys the fragment carries,
  `attribution`, `autoMemoryEnabled`, `promptSuggestionEnabled`,
  `awaySummaryEnabled` and optional
  `env.CLAUDE_CODE_SUBAGENT_MODEL` support (not activated in the shared fragment).
  The PATH check does not certify SDK/IDE runtimes; other local env keys are preserved. The
  whitelist also admits `permissions.defaultMode`, `permissions.deny` (allowlisted
  entries, merged by union, ADR-0054) and the two skip prompts, and refuses any
  other key. Nothing is read back into the repo.
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

## Durable daemon (gromarchy, personal scope)

`durable/` is an independent Node 26 adapter with its own exact dependency pins
and `bun.lock`. Install its dependencies with `cd durable && bun install
--frozen-lockfile`, then build the browser client with `bun run build` (it
writes the git-ignored `durable/web/app.js` and `style.css`). To update a
deployed checkout: `git pull`, then `cd durable && bun install
--frozen-lockfile && bun run build`; rollback and the build window are in
`durable/web/README.md`. Verify with `scripts/verify-agentic-infra durable`. It reads
the checkout's shared workflow contracts, guard implementations and model
registry at runtime. Routes, templates and contract text are read for subsequent
requests; imported guard implementations take effect after a daemon restart.

New runs start on GLM, or on Sol with `run --plan`. Plan tools keep an
`EtabliPlanDoc` in SQLite, with no `PLAN.md` or `docs/plan/` projection. A current
independent plan review gates READY and the next request switches to GLM;
`plan_escalate` records the reason for Astra. Reviews create fresh task-owned
children with read tools only and exclude every author family through the
shared registry. Mixed OpenAI/Z.ai authors use the bounded read-only Opus CLI;
unavailable eligible reviewers block the run. Three BLOCK rounds on the same
change also block it. All four axes must finish with valid coverage; the final
independent adversary arbitrates the round, while raw hunter verdicts remain
in the store. BLOCK counting uses that final verdict. A section edit after
READY reopens CHALLENGED and returns to the planner.

The `publish` tool requires complete reviews of the exact committed change,
checks the shared PR body contract and scans commits for secrets, pushes only
the run branch, reconciles an existing PR, records its URL and ends `done`.
Direct push and PR creation in workflow runs must use this tool. Direct merge
and default-branch pushes stay blocked. These invocation controls leave
arbitrary Bash and indirect API access unconfined. An answer without publication
ends `blocked`. Migrated Slice 2 runs retain their answer-only behavior and
terminal runs are never queued for publication. A stopped run with a persisted
publication intent and no URL performs one bounded read-only existing-PR lookup
before notification and archive. The outcome is stored, including lookup failure;
this recovery never pushes or creates a PR, and keeps the stop reason.
Schedules and MCP arrive in later slices.

Startup requires host `gromarchy`, an explicit `personal` value in
`~/.etabli-scope`, and a readable, nonempty `~/.config/etabli/work-orgs` with one
valid organization per line. Missing or invalid scope/deny-list configuration
refuses startup. Admission permits only `Tonours` and `tonours-dev` outside the
work deny list. Admission resolves the canonical owner through `gh repo view`
and checks existing cache fetch/push remotes before creating a run. No scope file or service is installed automatically.

Each new workflow run also gets a final SQLite snapshot under
`STATE/final/RUN_ID.sqlite` after notification is claimed. It is read-only and
never replaced; daily backups remain separate and retain fourteen snapshots.

The launcher is `scripts/etabli-durable`. The user units under `durable/systemd/`
expect this checkout at `%h/work/etabli` and Node 26 on the systemd user manager's
`PATH`. If the installation lives elsewhere, adapt both units' `WorkingDirectory`
and `ExecStart` before linking them into `~/.config/systemd/user/`. Then reload
user units and enable `etabli-durable.service` and
`etabli-durable-backup.timer`. The daemon uses `Restart=always`; the daily timer
uses `sqlite3 .backup` against the live WAL store.

Optional `etabli-durable-monitor.service` and `etabli-durable-monitor.timer`
use the same checkout convention. The timer runs at08:00 Europe/Paris and
writes private operational reports without modifying runs or repositories.
See `durable/monitoring.md` for installation, report limits and rollback.

Optional `~/.config/etabli/durable.json`:

```json
{
  "maxTurns": 64,
  "wallMs": 14400000,
  "restartLimit": 5,
  "notifyArgv": ["/absolute/path/to/notify-program"]
}
```

A terminal notification appends four arguments: run id, status, reason, PR URL
(empty when no PR was opened). No shell evaluates this array. Delivery is claimed in SQLite
before invocation, so it is attempted at most once; a crash after the claim or a
failed command is not retried. Prompts and credentials are never notification
arguments. Limits can be lowered up to a maximum of 256 turns and four hours;
start times and deadlines survive restarts. A third run remains queued behind
two busy conversations.
`restartLimit` bounds recovery attempts per native task (1 to 32, default 5).
The ten-cut qualification uses 12. Direct git/gh commands with unresolved shell
expansions or multiline comments fail closed; quote literal arguments and use
simple command segments for supported invocations.

```bash
scripts/etabli-durable run --repo Tonours/etabli --request-id my-fixture 'small fixture task'
scripts/etabli-durable run --plan --repo Tonours/etabli 'plan-route task'
scripts/etabli-durable plan RUN_ID
scripts/etabli-durable ls
scripts/etabli-durable show RUN_ID
scripts/etabli-durable steer RUN_ID 'additional instruction'
scripts/etabli-durable abort RUN_ID
```

Remote access is disabled until `durable.json` contains an `api` object:

```json
{"api": {"port": 4318, "identities": ["owner@example.invalid"]}}
```

The login strings must exactly match Tailscale's `Tailscale-User-Login` values.
Restart the daemon after changing configuration. The remote listener binds only
`127.0.0.1`; publish it with `tailscale serve --bg http://127.0.0.1:4318`.
Serve supplies TLS and replaces identity headers. Tagged clients have no user
login and are refused. Every TCP HTTP request and WebSocket upgrade requires
both the bearer token and an allowlisted login, including direct loopback calls.
The separate local Unix listener requires filesystem access instead. These
controls do not isolate other processes running under the same user.
Only Tailscale Serve is supported as the publishing proxy. Do not expose this
port directly or through a proxy that preserves client-supplied identity headers.

First daemon startup creates `STATE/api.token` as an owned `0600` regular file.
It survives restarts; malformed, symlinked or unsafe existing files stop startup.
Never print the token or put it in a URL, command argument, notification or log.
Provision a private `0600` token file on a client through a secure channel, then:

```bash
scripts/etabli-durable --host https://gromarchy.YOUR-TAILNET.ts.net --token-file /private/path/api.token ls
```

The client requires `--token-file` with `--host`; no implicit token path is used.
It accepts only an HTTPS origin, sends no identity override, and follows
no redirects. Removing the remote config and disabling Serve returns to local
CLI access. `tailscale serve --https=443 off` removes this proxy; preserve any
unrelated Serve configuration when operating a shared installation.

The API uses `GET/POST /v1/runs`, `GET /v1/runs/ID`, `GET /v1/runs/ID/plan`,
and `POST /v1/runs/ID/steer` or `/abort`. Creation takes `repo`, `prompt`,
`requestId`, and optional `route` (`answer` or `plan`); steering takes `content`
and `requestId`. Responses wrap results as `{ "ok": true, "value": ... }`.
`/v1/schedules` returns 501 until scheduling ships. HTTP bodies are bounded to
128000 UTF-16 units (at most 384000 UTF-8 bytes), preserving the former socket
input domain. Prompt and steering content remain limited to 64000 units.
An absent plan returns JSON `null`; the in-process dispatch still returns
`undefined`. Mutations use the existing native admission, steering and abort
semantics; abort resolves only after the conversation's tasks are idle.

A Node WebSocket client may open `/v1/runs/ID/watch` with an Authorization bearer
header through Serve. Each `{ "kind": "value", "value": ... }` message is the
current native conversation view, including live generation/tool state and a
bounded entry window. Reconnect with `?from=ENTRY_ID` to resume from that entry;
`before` identifies history outside the window. Consumers merge immutable entry
IDs and retain gaps rather than assuming a complete replay. Disconnects stop
the watch; quiet sockets use ping/pong instead of the HTTP idle timeout. Clients
with more than 4 MB of buffered view data are disconnected and can reconnect.
The stream is read-only; steering and abort use HTTP. Browser login and UI arrive
in later slices.

Local CLI requests use HTTP over the private `0600` Unix socket in
`~/.local/state/etabli-durable/` (`0700`). Only the daemon writes the store.
`flock` enforces process exclusivity and releases after SIGKILL; losing its lock
helper stops the daemon. A daemon-owned bare cache avoids altering the original
checkout. Each run has an ownerless native conversation, `feat/durable-<compact-run-id>` branch
and isolated worktree. Retrying a `--request-id` with the original input returns the same run. Different
content under an existing id is refused.
The daemon remembers the submitted route through a later answer-to-plan promotion.
A run promoted before this field existed compares against its stored route.

The credential adapter shares Pi 1.5.2's `~/.pi/agent/auth.json` lock protocol:
canonical realpath, `proper-lockfile`, 30-second stale threshold, five-second
heartbeat and bounded cancellable acquisition. Reads take the lock too because
Pi writes non-atomically. Daemon mutations reread under that lock and replace the
file atomically at `0600`, preserving other providers. Credential values never
enter conversation documents. Before a real run, qualify the compiled CLI using
`node durable/__tests__/qualify-credentials.ts`; it uses synthetic OAuth and
temporary `HOME`/`PI_CODING_AGENT_DIR` paths exclusively. `PI_CLI` can name the
compiled 1.5.2 binary. `node durable/__tests__/qualify-kills.ts` performs ten
synthetic process kills (three during an unsafe tool, seven during generation),
with a test-only restart limit of twelve.

Backups are private snapshots in `STATE/backups/`, atomically renamed after
SQLite completes. Only adapter-named snapshots are pruned, retaining fourteen.
To restore, stop the daemon, copy a completed snapshot to `store.sqlite` in a
separate empty `0700` state directory and set the copy to `0600`. Start
`scripts/etabli-durable --state /absolute/restore-state daemon`, then use the same
`--state` for `ls` and `show`. Run metadata retains its original worktree paths;
a restore into another state directory refuses to start active runs, so restore
drills should use completed runs. Active recovery requires the original state
path and its corresponding worktrees. Never replace a live store or copy its
WAL files independently.

### Durable terminal client

Run `scripts/etabli-durable tui` in an interactive terminal. It uses the private
Unix socket locally. Remote use accepts the same HTTPS origin and explicitly
named private token file as other CLI commands:

```bash
scripts/etabli-durable --host https://gromarchy.example.ts.net --token-file /private/api.token tui
```

The list groups runs under Needs you, In progress and Finished, each row with
a glyph and a status label (never colour alone), its age, repository and title;
the line under the list gives the selected run's next step and pull-request
URL. Use Up/Down to select a run and Enter to follow its stream. `s` opens the steer
input; Enter sends it and Escape keeps the draft while returning to the run.
`a` asks to abort the selected run; `y` confirms and Escape cancels. Escape from
the run returns to the list. `q` outside the input, or Ctrl-C anywhere, closes
the client without aborting a run. Page Up/Down scrolls the stream. `r` refreshes
the run list outside the steer input and abort confirmation.

The client polls run status and follows native WebSocket views. It retains at
most 100 recent entries, resumes after a disconnect, and labels omitted or
missed history. It shows text and tool progress; thinking and system messages
are hidden. Untrusted text and pasted drafts cannot emit terminal controls.
Plan editing, run creation and history paging are not part of this TUI.
The alternate screen and terminal input mode are restored on exit. A real
interactive terminal is required; other CLI commands remain usable headlessly.
