# Claude

You get the Claude Code side of etabli here: hooks, agents, settings fragments
and the work-scope scripts. Workflow rules live in
[`../workflow/spec.md`](../workflow/spec.md), and
[`../docs/symlink-layout.md`](../docs/symlink-layout.md) lists every managed
link. `scripts/check-fix-symlinks.sh` checks them, and `--fix` repairs them.

## Scopes

Skills live in the shared tree `../skills/<scope>/<name>/`, served to Claude
and Pi alike. Claude agents and scripts live under `claude/scopes/<scope>/`.

| Scope | Holds | Deployed |
|---|---|---|
| `shared` | Anything that does not name an employer or a private project | Always |
| `work` | Employer-specific surfaces: the employer stack, its repos, its conventions | Only where the machine declares it |
| `personal` | Private-project surfaces | Only where the machine declares it |

A machine declares one scope in `~/.etabli-scope`, containing exactly `work` or
`personal`. `ETABLI_SCOPE` overrides it for one run. No file and no variable
means `shared` alone, so a new machine never receives another context's
surfaces by accident. An unknown value fails the deploy with exit 2. The same
active scope gates vendored skills.

Put a surface in `shared` only if it would still make sense at a different
employer. A skill that names a repo, a product or an internal service belongs
in `work`. Vendored skills arrive through `vendor/`, and the `extras/` shelf
holds skills that are never deployed. Claude links every active-scope row of
`workflow/runtime/skill-surface.tsv`; Pi links only `pi_core=1` rows.

A `shared` surface is withheld from a scope when something else on that machine
owns its name. `SHADOWS` in `scripts/lib/surfaces.mjs` holds those pairs,
`work:adr` today. On a `work` machine the deploy only withholds the shared
`adr`: `/adr` comes from the employer plugin, which you install separately and
which writes `docs/adr/YYYY-MM-DD-slug.md`, while `scripts/validate-adrs`
expects `docs/adr/NNNN-slug.md`. Record etabli ADRs from a `personal` machine
or by hand.

`scopes/work/scripts/` holds the PR review scripts and `claude-bin.sh`, which
resolves the `claude` binary where no shell profile is loaded. Their launchd
plists stay in `~/Library/LaunchAgents/`: linking a script does not schedule it.

## Contracts, skills and agents

A `workflow/skills/<name>.md` contract is the cross-runtime source of truth. A
`skills/<scope>/<name>/SKILL.md` skill is the thin `/name` entry point on both
runtimes (Claude commands are retired, ADR-0037). Pi ignores the Claude-only
frontmatter keys (`argument-hint`, `allowed-tools`).
`tests/workflow-contract-coverage-smoke.sh` keeps every contract referenced.

Linear skills use the Linear MCP; PR review uses the `gh` CLI.

The custom agents are `scout` (read-only reconnaissance), `worker` (one step
from a `READY` plan, the only writing agent), `reviewer` (fresh-context diff
review) and `adversary` (a read-only red team that rebuilds intent from the
diff alone and never reads `PLAN.md`; the `/adversary` skill attacks plans). They declare `Skill`
and pick a domain skill themselves; no hook suggests one (ADR-0014). Skill
`allowed-tools` entries are pre-approvals, not a sandbox.

## Skill governance

`settings.skill-overrides.json` holds the skill map. Every repo and vendored
skill, plus `herdr` from the dotfiles repo, is either `on` (listed to the
model) or `user-invocable-only` (slash only). The `on` set must match the
pinned keep-set in `scripts/lib/claude-skill-load-check.mjs`. It includes the
`work` skills `pr-council-review` and `linear-ticket-create`, so the model can
call them on a work machine.

`scripts/claude-skill-load-check` runs after each live deploy and fails when:

- the model-facing skill index outgrows its gate (5280 characters);
- a skill on the surface is missing from the map;
- the `on` set drifts from the pinned keep-set;
- an enabled plugin ships skills.

`--fix` adds new skills as `user-invocable-only`.

Personal skills, outside the repo, are governed in the live
`~/.claude/settings.json`. The deploy keeps their states, drops entries whose
skill is gone from `~/.claude/skills`, and drops a personal `on` unless the
skill is named in `machine-local-skills.json` (today `alambic-brain`, `alambic-obvault`
and `fleet`, `on` on the machines that have them) or in the machine-local
`~/.config/etabli/machine-local-skills.json`, for a skill only one machine has. Plugins named in
`machine-local-plugins.json` (`datadog`) or in the machine-local
`~/.config/etabli/machine-local-plugins.json` may ship skills. They bring an MCP
server, hooks or agents that vendoring would break, so their skills stay
ungoverned and outside the index gate.

## Hooks

- `read-only-agent-guard.mjs` is wired by the `scout`, `reviewer` and
  `adversary` frontmatter. It allows only Bash it can prove read-only,
  including an allowlisted set of read-only `gh` commands. One exception
  writes: a plain `git fetch` is allowed, and it updates `.git/` and the
  remote-tracking refs. It fails closed: on
  shell tricks it cannot prove harmless, on executables outside system bin
  directories, on every call if its modules fail to load, and on unreadable
  hook input (exit 2). The frontmatter command ends with `|| exit 2`, so a
  missing script or a crashed `node` blocks Bash too. A guard stalled past its
  10 s `timeout` is killed and blocks Bash (`onFailure: block`, Claude Code
  2.1.295 or later).
  `tests/claude-hooks-smoke.sh` holds the accepted and refused cases.
- `no-comments-guard.mjs` (`PreToolUse` on `Edit|Write|MultiEdit`) is a thin
  adapter over `workflow/runtime/no-comments-guard.mjs`, the detector Pi uses
  too. It denies a write that adds a code comment to a file whose extension it
  knows; any other file, extensionless scripts included, passes. It lets
  through tool directives, shebangs, comments already on disk, doc comments (`///`, `//!`,
  `/** */`, a shell file's leading `#` block) and any write outside a git work
  tree. It cannot see files written through `Bash`. It is a per-language
  lexer, not a parser: shell grammar beyond strings, heredocs and substitutions
  (a `case` pattern inside `$(...)` included) is lexed as plain code, which can
  miss or add a comment.
- `pr-body-guard.mjs` (`PreToolUse` on `Bash`) is a thin adapter over
  `workflow/runtime/pr-body-guard.mjs`, shared with the Pi `pr-body.ts`
  extension. It checks two things.
  - **PR bodies.** It denies a `gh pr create` or `gh pr new` without a body,
    or a `gh pr create`, `new` or `edit` body that misses `## What`, `## Why`,
    `## How to test` (unless the repo template has its own what-changed and
    verification headings) or the repo template's headings, carries AI
    attribution, or has non-ASCII prose outside code, tables and quotes. It
    checks every `gh pr` invocation of the line with its own body: inline, a
    heredoc, a `--body-file` resolved after a `cd`, or `--body-file -` fed
    by a heredoc, a here-string or `< file`. A body it cannot read (built at
    run time, piped, missing, unreadable, or a relative file behind a `cd` it
    cannot resolve) passes that invocation unchecked; the other invocations
    and commits of the line are still checked.
  - **Commit messages.** In every repo, it denies a `git commit` whose literal
    `-m`, `-F` or `--trailer` text carries a `Claude-Session:` or
    `Co-Authored-By:` trailer, or an AI credit such as "Generated with Claude".
    Other trailers and extra `-m` paragraphs pass, so the subject-only rule of
    `workflow/git-contract.md` stays a convention.
  - In a repo whose GitHub org is listed in `~/.config/etabli/work-orgs`
    (`ETABLI_WORK_ORGS_FILE` overrides the path), both checks also refuse a
    non-Claude model or provider name such as GPT, Codex or Gemini. A name in a
    code span or fence passes.

  It masks quoted strings, heredocs and comments. A commit message built at
  run time (`-m "$MESSAGE"`) passes unchecked too. It does not see `gh api` calls, a command nested
  inside `bash -c`, `eval` or a double-quoted `"$(...)"`.
- `no-comments-guard.mjs` and `pr-body-guard.mjs` fail open: a crash lets the
  write or the command through, since neither guards a read-only boundary.

`settings.workflow-hooks.json` is a merge fragment. The installer links it but
does not merge it, because the live settings file can hold secrets. Run
`scripts/claude-hooks-merge --dry-run`, then `scripts/claude-hooks-merge`. It
adds the fragment's hooks, removes only hooks the repo retired (`rtk-guard.mjs` included; a bare
`rtk hook claude` stays, ADR-0049), backs up first, refuses invalid JSON, and never
reads secrets back into the repo. Rerun it after a deploy that adds a hook,
then verify with `scripts/claude-hooks-check`.

## Autonomous mode

Claude Code runs without permission prompts on this machine. The tracked
fragment `settings.skill-overrides.json` carries the skill map plus
`attribution: { commit: "", pr: "" }` (no AI trailer or PR line) and
`autoMemoryEnabled: false`, since durable memory is the vault plus the
`PLAN.md` handoff. `promptSuggestionEnabled: false` and
`awaySummaryEnabled: false` turn off generated next-prompt suggestions and
automatic away recaps. These managed scalars win over local values at each
deploy; changing a toggle in `/config` lasts only until the next sync.
`CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION` and `CLAUDE_CODE_ENABLE_AWAY_SUMMARY`
can override them; sync preserves those environment values. Permissions are
not changed by these defaults; the token-usage keys below (ADR-0051) are.
`scripts/lib/claude-settings-sync.mjs` copies only
whitelisted keys into `~/.claude/settings.json`, so no secret can leak into the
fragment. `permissions.defaultMode: "bypassPermissions"` and the two skip flags
stay in the local settings file. No hook gates pushes, deletions or `PLAN.md`
writes (ADR-0032).

Use `/goal <measurable done condition, validation command, constraints, stop
limit>` for till-done loops. Pi and Claude orchestration parity lives in
[`../workflow/skills/orchestration.md`](../workflow/skills/orchestration.md).

The fragment also tracks the token-usage keys (ADR-0051):
`env.CLAUDE_CODE_SUBAGENT_MODEL: "sonnet"`,
`env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS: "100000"`, `modelSettings` effort
`medium` for `claude-opus-5-5` and `claude-sonnet-5-5`,
`autoCompactWindow: 200000`, `bashOutputMaxChars: 15000` and
`skillListingMaxDescChars: 400`. Every runtime on the three hosts was
inventoried at 2.1.292 or newer before the subagent-model default was
activated. An explicitly tracked key overwrites its local value; other local
keys and values (other `env` entries, other `modelSettings` models and
fields such as `maxEffortLevel` or a per-model `autoCompactWindow`) are
preserved without logging; a per-model window that overrides the tracked one
draws a warning naming the model only. Removing a key from the fragment
leaves the local value in place. On Claude Code >=2.1.251, the subagent
model is a default for subagents with no explicit model: per-call model and
agent frontmatter (including `inherit`) take precedence. Explicit Opus
adversaries remain Opus.
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is not managed and the writer rejects it
as a tracked key; if set by the user, native forced-model behavior still
applies. Older Claude versions gave the default env key higher precedence;
upgrade before using this policy. See the
[native model resolution order](https://code.claude.com/docs/en/sub-agents#choose-a-model).
The PATH version probe is a partial check, not certification of other runtimes.
Sync probes `claude --version` on PATH (5 s cap) and gates each key on its
documented minimum: subagent model and per-model effort 2.1.251, Bash cap
2.1.261, compaction window 2.1.288, idle threshold 2.1.299; the skill
description cap has no documented minimum and is ungated. On an old, missing
or unrecognized runtime, sync warns per skipped key, naming its minimum;
satisfied and ungated keys still sync. Out-of-bounds tracked values are
refused before any backup or write (never silently clamped). Existing local
env values remain untouched. `scripts/deploy-agent-workflow --check` on a
live home reports tracked-settings drift as an unresolved issue naming
`--apply`, without writing.
Council launchers exclude user settings but do not scrub an inherited process
env: a model-less descendant can receive this default from a Claude caller.
Explicit reviewer models, effort and turn limits stay unchanged. Plugin
`model: inherit` remains explicit. No measured token saving is established.

## Token usage and session continuity

The statusline labels `parent(last)` as the last parent request and
`session(native-est)` as the client's native session USD estimate, not a bill,
quota, or verified whole-tree token total. `subagents:inconnu` remains explicit
because that payload does not provide their token breakdown.

Existing review logs use native `modelUsage` totals, which include reported
subagent requests according to the
[native accounting contract](https://code.claude.com/docs/en/agent-sdk/cost-tracking).
They are grouped by model, not individual parent/child. `scope=native-session-cumulative`
and `restored=possible` mean that resumes, copies and forks can include an
opening balance. **Never add overlapping snapshots of a resumed/copied/forked
session.** Only proven independent calls can have their totals added. With
an unknown opening balance, new consumption is unknown. Pricing `basis` is
`list`, `managed`, or `unknown`; a native zero is valid, but error/crash zeros
do not prove no spend. Keep `is_error` and `subtype` beside the estimate.
Thinking is already included in output tokens, not a second amount to add.

To inspect a final native JSON already retained privately, without another
model call or a history scan:

```bash
jq '{scope:"native-session-cumulative",restored:"possible",total_cost_usd,is_error,subtype,modelUsage}' "$private_result_json"
```

Missing counters stay unknown. A native final result covers what the runtime
reported; background exit deadlines can leave work unreported. Keep task
success, input/cache-write/cache-read/output, USD estimate, account quota and
latency separate. Compare the same task and quality, including failed branches
and rework; no measured saving follows from these labels or fixture tests.

Use `/context` to inspect actual loaded instructions and `/usage` for the
native account/session view. Imports in `CLAUDE.md` are eager; skills load their
body on invocation and then remain in history. Keep specialized material cold,
read decisive files/ranges, and retain full logs privately with exit status and
proof references. Use ToolSearch on supported MCP routes instead of loading
all schemas; do not toggle servers or models needlessly mid-task. The delegation choices and
handoff rules live in `workflow/skills/orchestration.md`; no review gate changes.

For remote follow-up, first identify the machine, directory and session doing
the job. Prefer its existing session to re-explaining the task on another Mac:

| Intent | Native action | Boundary |
| --- | --- | --- |
| Expose the running interactive session | `/rc` inside that session | Documented by Claude; not a CLI `--help` or live mobile test |
| Start a new interactive session with remote access | `claude --remote-control` | A new session, not attachment to the old one |
| Resume the last server-recorded session | `claude remote-control --continue` | Server record for that directory; can expire or fail; not an ordinary interactive session |
| Resume a specific server session | `claude remote-control --session-id <id>` | Cannot combine with spawn flags or `--continue`; server defaults can still allow additional sessions |
| Intentionally start one new server session | `claude remote-control --spawn=session` | Explicitly new work; not a fallback after failed attachment |

Only CLI help/syntax was checked locally; no server, account eligibility or
mobile connection was exercised for these recipes. Do not launch a second
copy or retry a failed resume as new work automatically.
An attached multi-session server can still accept new requests; capacity is
not a token budget, and same-directory writers can conflict. For independent
concurrent jobs, retain the workflow's worktree isolation. Remote Control runs
locally; cloud sessions and `/remote-env` are different execution environments.
Remote access has no documented intrinsic token discount. Availability depends
on account, policy, provider and runtime; this change enables no server or
service. See [Remote Control](https://code.claude.com/docs/en/remote-control).

Keep caching enabled and avoid opportunistic model changes on a large warm
history. Longer TTLs cost more to write and need evidence before adoption.
After persisting the handoff, use `/clear` only for unrelated work. At a
natural task boundary, `/compact Keep decisions, constraints, checked results,
open findings and the next action` preserves continuity; never run it on a timer.
Fast mode buys latency at a higher price; it is not a cost optimization.
The two optional background defaults above do not disable compaction or a
mandatory evaluator. The sourced research and proposed comparison protocol are
in [`20261109-claude-code-token-optimization.md`](../docs/research/20261109-claude-code-token-optimization.md).

### Tracked cost settings

The tracked fragment carries the cost settings that must hold on every
machine. `scripts/lib/claude-settings-sync.mjs` merges them into
`~/.claude/settings.json` at deploy; an explicitly tracked key overwrites its
local value, and removing a key from the fragment leaves the local value in
place.

| Key | Value | Minimum Claude Code |
|---|---|---|
| `env.CLAUDE_CODE_SUBAGENT_MODEL` | `"sonnet"` | 2.1.251 |
| `env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS` | `"100000"` | 2.1.299 |
| `modelSettings.claude-opus-5-5.effortLevel` | `"medium"` | 2.1.251 |
| `modelSettings.claude-sonnet-5-5.effortLevel` | `"medium"` | 2.1.251 |
| `autoCompactWindow` | `200000` | 2.1.288 |
| `bashOutputMaxChars` | `15000` | 2.1.261 |
| `skillListingMaxDescChars` | `400` | none (ungated) |
| `permissions.deny` | six unused tools and agent types (ADR-0054) | none (ungated) |

A gated key is skipped with a warning naming its minimum version when
`claude --version` on PATH is older, absent, failing or unreadable; the
ungated and satisfied keys still sync. `skillListingMaxDescChars` has no
documented minimum and always syncs, since an older client ignores a key it
does not know. A local `modelSettings.<id>.autoCompactWindow` overrides the
tracked window in the same file, and the sync warns about it without printing
its value.

`permissions.deny` merges by union instead of overwriting: local entries stay
in place, missing tracked entries are appended, and `--check` reports drift
only while a tracked entry is missing. The writer accepts only entries from
its allowlist and refuses a malformed local `permissions` or `deny` before
any backup. To roll an entry back, strike it from the fragment, then delete
it from `permissions.deny` in each host's `~/.claude/settings.json` or
restore the writer's backup.

Measure with `scripts/claude-usage-audit --days 7` before and seven days
after a settings change (ADR-0050): one JSON object of aggregates over the
transcript tree, never message content, kept on the host because it names
project basenames, tools, MCP servers and subagent types. `j_carriedVsUsed`
sets the tools, MCP servers and agent types each new session carried against
the ones called in the window (a spawned type no listing names prints as
`(other)`); `schema.toolScanGaps` above 0 means some calls may be missing
from it.

`scripts/deploy-agent-workflow --check` also flags an `rtk` on PATH whose
owner-installed hook cannot run from a live Claude root: no
`hooks.PreToolUse` group matching `Bash` runs `rtk hook claude`, or
`disableAllHooks` turns every hook off. The command is read as shell words,
quotes and backslashes removed; a command substitution among its first words
counts as no hook. Run `rtk init -g --hook-only` for the
reported root. Unset `CLAUDE_CONFIG_DIR` for `~/.claude` or set it to the
reported directory for an override. RTK and its hook are owner-installed
(ADR-0049). The check stays silent when `rtk` is absent.

## PR autoreview

Review usage and timing share `~/.claude/logs/pr-review-usage.log`. The target
field is `repo#PR@<40-character-head-SHA>` across council, watcher verification,
delta and autoreview, so runs on different commits stay distinct. Legacy rows
without a SHA remain unbound; never infer one. Compare native input/cache-write/
cache-read/output categories and task outcomes on matching scopes. These logs can
be inspected alongside Fleet measurements; no automatic Fleet log importer or
measured token saving is implied.

`scopes/work/scripts/pr-autoreview/` reviews your own PRs. A husky `pre-push`
hook detaches a runner that waits for the pushed head, checks that the PR
author is the `gh` user, and reviews the PR against `profiles/<profile>.md`,
the repo's `CLAUDE.md` and `~/work/brain`.

- Enrolled repositories live in the machine-local
  `~/.claude/state/pr-autoreview/repos.tsv` (`<owner/repo><TAB><profile>`). No
  file means no review.
- Findings go to Slack `#routines` only (`prompt.md`).
- Guards: a PR under 31 days old (counted in whole days), one pass per `repo#pr@headSha`, one run per
  PR, and the kill switch `~/.claude/state/pr-autoreview.off`.
- A fleet thread pushing the branch fleet records for it (`threads.branch`
  of `FLEET_THREAD`), from the worktree fleet records (`threads.dir`) to that
  worktree's origin repo, is skipped so worker pushes do not emit duplicate
  Slack autoreview reports. Any other push from the pane, or an
  unreadable fleet database, is reviewed as usual.
- A later push is reviewed on the commits since the last reviewed head (the
  full diff after a rebase or a new base), and posts nothing when it finds
  nothing.

`pr-autoreview/install.sh` wires a machine.

## Failure ownership

Name the owner before fixing: a failure goes to the layer whose check fails.

| Failure | Owner | Recovery |
| --- | --- | --- |
| Dangling, foreign or shadowed managed link | Etabli deploy | `scripts/check-fix-symlinks.sh --fix` |
| Claude skill missing or ungoverned | Etabli skill governance | `scripts/claude-skill-load-check --fix` |
| Pi skill block wrong, stale backup loaded | Etabli Pi surface | `scripts/pi-skill-load-check`, then fix what each `FAIL` line names |
| Hook missing or settings drift on a live home | Etabli settings sync | `scripts/deploy-agent-workflow --apply`, then `scripts/claude-hooks-check` |
| Council run fails, vetoes (exit 3) or ends incomplete (exit 4) | work-scope council script | rerun `~/.claude/scripts/pr-council-review/run.sh <N>` on the same head |
| Fleet daemon, thread or herdr pane failure | Fleet or herdr, outside this repo | `scripts/deploy-agent-workflow --check` green on that host clears Etabli; fix it in its own repo |
| Runtime bug in Claude Code, Pi or Codex | the runtime | `scripts/verify-agentic-infra core` green clears Etabli; report it upstream |

## What's next

[`../docs/symlink-layout.md`](../docs/symlink-layout.md) shows where each of
these files lands in your home.
