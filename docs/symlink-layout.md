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

## Durable daemon (gromarchy, personal scope)

`durable/` is an independent Node 26 adapter with its own exact dependency pins
and `bun.lock`. Install its dependencies with `cd durable && bun install
--frozen-lockfile`; verify with `scripts/verify-agentic-infra durable`. It reads
the checkout's shared workflow contracts, guard implementations and model
registry at runtime. Updating those files therefore changes subsequent requests.

Slice 2 accepts small tasks that need no plan. Its native GLM conversation can
read, write, edit and run Bash in a separate worktree; `done` means that the
conversation answered. Plan documents, phase routing, review tools, publication,
HTTP access, schedules and MCP arrive in later slices. Direct merge and
default-branch pushes are already blocked. These command guards are invocation
controls; arbitrary Bash and indirect API access remain unconfined.

Startup requires host `gromarchy`, an explicit `personal` value in
`~/.etabli-scope`, and a readable, nonempty `~/.config/etabli/work-orgs` with one
valid organization per line. Missing or invalid scope/deny-list configuration
refuses startup. Admission permits only `Tonours` and `tonours-dev` outside the
work deny list. Admission resolves the canonical owner through `gh repo view`
and checks existing cache fetch/push remotes before creating a run. No scope file or service is installed automatically.

The launcher is `scripts/etabli-durable`. The user units under `durable/systemd/`
expect this checkout at `%h/work/etabli` and Node 26 on the systemd user manager's
`PATH`. If the installation lives elsewhere, adapt both units' `WorkingDirectory`
and `ExecStart` before linking them into `~/.config/systemd/user/`. Then reload
user units and enable `etabli-durable.service` and
`etabli-durable-backup.timer`. The daemon uses `Restart=always`; the daily timer
uses `sqlite3 .backup` against the live WAL store.

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
(empty in Slice 2). No shell evaluates this array. Delivery is claimed in SQLite
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
scripts/etabli-durable ls
scripts/etabli-durable show RUN_ID
scripts/etabli-durable steer RUN_ID 'additional instruction'
scripts/etabli-durable abort RUN_ID
```

CLI requests use only the private `0600` Unix socket in
`~/.local/state/etabli-durable/` (`0700`). Only the daemon writes the store.
`flock` enforces process exclusivity and releases after SIGKILL; losing its lock
helper stops the daemon. A daemon-owned bare cache avoids altering the original
checkout. Each run has an ownerless native conversation, `feat/durable-<compact-run-id>` branch
and isolated worktree. Retrying a `--request-id` returns the same run; different
content under an existing id is refused.

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
