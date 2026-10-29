# Claude

This directory gives you the Claude Code side of `etabli`: hooks, agents,
settings fragments and the work-scope scripts. Workflow rules live in
`../workflow/spec.md`, and `../docs/symlink-layout.md` lists every managed
link. `scripts/check-fix-symlinks.sh` checks them; add `--fix` to repair.

## Scopes

Skills live in the shared tree `../skills/<scope>/<name>/`, served to Claude
and Pi alike; Claude agents and scripts live under `claude/scopes/<scope>/`:

| Scope | Holds | Deployed |
|---|---|---|
| `shared` | Anything that does not name an employer or a private project | Always |
| `work` | Employer-specific surfaces (employer stack, its repos, its conventions) | Only where the machine declares it |
| `personal` | Private-project surfaces | Only where the machine declares it |

A machine declares one scope in `~/.etabli-scope`, containing exactly `work` or
`personal`. `ETABLI_SCOPE` overrides it for one run. No file and no variable
means `shared` alone, so a new machine never receives another context's
surfaces by accident. An unrecognised value fails the deploy with exit 2. The
same active scope gates vendored skills linked into Pi and Claude.

Put a surface in `shared` only if it would still make sense at a different
employer. A skill that names a repo, a product, or an internal service belongs
in `work`. Vendored skills arrive through `vendor/`; optional skills sit on the
`extras/` shelf and are not deployed by default. Claude links every active-scope
row of `workflow/runtime/skill-surface.tsv`; Pi links only `pi_core=1` rows.

A `shared` surface is withheld from a scope when something else on that machine
owns its name: `SHADOWS` in `scripts/lib/surfaces.mjs` holds `<scope>:<skill>`
pairs, currently `work:adr`. On a `work` machine `/adr` therefore comes from the employer plugin,
which writes `docs/adr/YYYY-MM-DD-slug.md`; this repo's `scripts/validate-adrs`
expects `docs/adr/NNNN-slug.md`, so record etabli ADRs from a `personal`
machine or by hand.

`scopes/work/scripts/` holds the PR review scripts and `claude-bin.sh`, which
resolves the `claude` binary where no shell profile is loaded. Their launchd
plists stay in `~/Library/LaunchAgents/`: linking a script does not schedule it.

## Contracts, skills and agents

A `workflow/skills/<name>.md` contract is the cross-runtime source of truth; a
`skills/<scope>/<name>/SKILL.md` skill is the thin `/name` entry point on both
runtimes (Claude commands are retired, ADR-0037). Pi ignores the Claude-only
frontmatter keys (`argument-hint`, `allowed-tools`).
`tests/workflow-contract-coverage-smoke.sh` keeps every contract referenced.

`/verify-workflow` is the workflow verifier; Claude Code's native `/verify`
stays free for app verification. Linear commands use Linear MCP; PR review uses
the `gh` CLI.

Custom agents: `scout` (read-only reconnaissance), `worker` (one step from a
`READY` plan, the only writing agent), `reviewer` (fresh-context diff review)
and `adversary` (read-only plan or diff review). They declare `Skill` and pick
a domain skill themselves; no hook suggests one (ADR-0014). Skill
`allowed-tools` entries are pre-approvals, not a sandbox.

## Skill governance

`settings.skill-overrides.json` holds the skill map: every repo and vendored
skill, plus `herdr` (linked from the dotfiles repo), is `on` (listed to the
model) or `user-invocable-only` (slash only).
`scripts/claude-skill-load-check` runs after each live deploy (skipped by
`ETABLI_SKIP_LIVE_CHECKS=1`) and fails when the
model-facing index outgrows its gate, a skill on the surface is missing from
the map, the `on` set drifts from the pinned keep-set, or an enabled plugin
ships skills. `--fix` adds new skills as `user-invocable-only`.

Personal skills (outside the repo) are governed in the live
`~/.claude/settings.json`; deploy keeps their states, drops entries whose skill
is gone from the surface, and drops a personal `on` unless the skill is named
in `machine-local-skills.json` (today the
`alambic-brain` and `alambic-obvault` memory skills and `fleet`, `on` on the
machines that have them). Plugins named in `machine-local-plugins.json` (`datadog`) or in the machine-local
`~/.config/etabli/machine-local-plugins.json` (work plugins)
may ship skills: they bring an MCP server, hooks or agents that vendoring would
break, so their skills stay ungoverned and outside the index gate.

## Hooks

- `read-only-agent-guard.mjs` is wired by `scout`, `reviewer` and `adversary`
  frontmatter. It allows only Bash it can prove read-only, including an
  allowlisted set of read-only `gh` commands, and fails closed: on shell tricks
  it cannot prove harmless, on executables outside system bin directories, on
  every call if its modules fail to load, and on unreadable hook input (exit 2).
  The frontmatter command ends with `|| exit 2`, so a missing script or a
  crashed `node` blocks Bash too.
  `tests/claude-hooks-smoke.sh` holds the accepted and refused cases.
- `no-comments-guard.mjs` (`PreToolUse` on `Edit|Write|MultiEdit`) is a thin
  adapter over `workflow/runtime/no-comments-guard.mjs`, the detector Pi uses
  too. It denies a write that adds a code comment; tool directives, shebangs
  and comments already on disk are kept. It cannot see files written through
  `Bash`. It is a per-language lexer, not a parser: shell grammar beyond
  strings, heredocs and substitutions (a `case` pattern inside `$(...)`
  included) is lexed as plain code, which can miss or add a comment.
- `rtk-guard.mjs` (`PreToolUse` on `Bash`) forwards a command to
  `rtk hook claude` only when `workflow/runtime/rtk-data-flow.mjs` allows
  compaction, and runs the rest raw.
- `no-comments-guard.mjs` and `rtk-guard.mjs` fail open: a crash lets the write
  or the raw command through, since neither guards a read-only boundary.

`settings.workflow-hooks.json` is a merge fragment, linked but not merged by
the installer because the live settings file can hold secrets. Run
`scripts/claude-hooks-merge --dry-run`, then `scripts/claude-hooks-merge`: it
adds the fragment's hooks, removes only hooks the repo retired (including a bare
`rtk hook claude`), backs up first, refuses invalid JSON, and never reads
secrets back into the repo. Rerun it after a deploy that adds a hook; verify
with `scripts/claude-hooks-check`.

## Autonomous mode

Claude Code runs without permission prompts on this machine. The tracked
fragment `settings.skill-overrides.json` carries the skill map plus
`attribution: { commit: "", pr: "" }` (no AI trailer or PR line) and
`autoMemoryEnabled: false` (durable memory is the vault plus the `PLAN.md`
handoff). `scripts/lib/claude-settings-sync.mjs`, run by the installer, copies
only whitelisted keys into `~/.claude/settings.json`, so no secret can leak into
the fragment. `permissions.defaultMode: "bypassPermissions"` and the two skip
flags stay in the local settings file. No hook gates pushes, deletions, or
`PLAN.md` writes (ADR-0032).

Use `/goal <measurable done condition, validation command, constraints, stop
limit>` for till-done loops. Pi/Claude orchestration parity:
`../workflow/skills/orchestration.md`; Task* state is Pi-only.

## PR autoreview

`scopes/work/scripts/pr-autoreview/` reviews the user's own PRs. A husky
`pre-push` hook detaches a runner that waits for the pushed head, checks the PR
author is the `gh` user, and reviews it against `profiles/<profile>.md`, the
repo's `CLAUDE.md` and `~/work/brain`. Enrolled repositories live in the
machine-local `~/.claude/state/pr-autoreview/repos.tsv` (`<owner/repo><TAB><profile>`);
no file means no review. Break-in mode: findings go to Slack `#routines` only
(`prompt.md`). Guards: PR younger than 30 days, one pass per
`repo#pr@headSha`, one run per PR, kill switch
`~/.claude/state/pr-autoreview.off`. `pr-autoreview/install.sh` wires a machine.

## PR review watch

`scopes/work/scripts/pr-review-watch/` reviews PRs where the user's review is
requested (never the user's own PRs). A LaunchAgent runs `watch.sh` every 300 s:
it watches open PRs until closed, approved or no longer involving the user,
reviews a head sha after 600 s of quiet, skips diffs above 5000 lines, runs at
most 2 reviews at once and 20 a day, and retries a failed review 3 times. Each
review opens in a `pr-reviews` herdr tab, or runs detached.

The first review is `/pr-council-review --post`, which also reads open PRs
linked to this one in the owner's repositories and turns a finding one of
them already fixes into a merge-order note; later pushes get
`/code-review` on the new commits, then the machine-local fix-verification
skill (`PR_COUNCIL_VERIFY_SKILL`, else the first line of
`~/.config/pr-council-review/verify-skill`). Without one, that step is marked
unconfigured and the head stays due. A head whose full review found nothing,
with no review of yours on the PR, skips the step and needs no verify skill.
The watch approves only when the model is confident and its own checks hold
(head unchanged, PR open and not draft, no unresolved thread, no other changes
requested, CI green). Agent config files a PR changes are reset to base in every
scratch worktree. State: `~/.claude/state/pr-review-watch/`; logs:
`~/.claude/logs/pr-review-watch.log` and `pr-review-usage.log`. `watch.sh stop`
sets the kill switch and stops reviews in flight. `tests/pr-review-gates-smoke.sh`
covers the approval gates.
