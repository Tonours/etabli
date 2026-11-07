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

`/verify-workflow` is the workflow verifier, so Claude Code's native `/verify`
stays free for app verification. Linear skills use the Linear MCP; PR review
uses the `gh` CLI.

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
  missing script or a crashed `node` blocks Bash too.
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
- `rtk-guard.mjs` (`PreToolUse` on `Bash`) forwards a command to
  `rtk hook claude` only when `workflow/runtime/rtk-data-flow.mjs` allows
  compaction, and runs the rest raw.
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
    by a heredoc, a here-string or `< file`. A body piped into
    `--body-file -` is refused, since the guard cannot read it.
  - **Commit messages.** In every repo, it denies a `git commit` whose literal
    `-m`, `-F` or `--trailer` text carries a `Claude-Session:` or
    `Co-Authored-By:` trailer, or an AI credit such as "Generated with Claude".
    Other trailers and extra `-m` paragraphs pass, so the subject-only rule of
    `workflow/git-contract.md` stays a convention.
  - In a repo whose GitHub org is listed in `~/.config/etabli/work-orgs`
    (`ETABLI_WORK_ORGS_FILE` overrides the path), both checks also refuse a
    non-Claude model or provider name such as GPT, Codex or Gemini. A name in a
    code span or fence passes.

  It masks quoted strings, heredocs and comments, and refuses a PR body built
  at run time. A commit message built at run time (`-m "$MESSAGE"`) passes
  unchecked. It does not see `gh api` calls, a command nested
  inside `bash -c`, `eval` or a double-quoted `"$(...)"`.
- `no-comments-guard.mjs`, `pr-body-guard.mjs` and `rtk-guard.mjs` fail open: a
  crash lets the write or the raw command through, since none guards a
  read-only boundary.

`settings.workflow-hooks.json` is a merge fragment. The installer links it but
does not merge it, because the live settings file can hold secrets. Run
`scripts/claude-hooks-merge --dry-run`, then `scripts/claude-hooks-merge`. It
adds the fragment's hooks, removes only hooks the repo retired (a bare
`rtk hook claude` included), backs up first, refuses invalid JSON, and never
reads secrets back into the repo. Rerun it after a deploy that adds a hook,
then verify with `scripts/claude-hooks-check`.

## Autonomous mode

Claude Code runs without permission prompts on this machine. The tracked
fragment `settings.skill-overrides.json` carries the skill map plus
`attribution: { commit: "", pr: "" }` (no AI trailer or PR line) and
`autoMemoryEnabled: false`, since durable memory is the vault plus the
`PLAN.md` handoff. `scripts/lib/claude-settings-sync.mjs` copies only
whitelisted keys into `~/.claude/settings.json`, so no secret can leak into the
fragment. `permissions.defaultMode: "bypassPermissions"` and the two skip flags
stay in the local settings file. No hook gates pushes, deletions or `PLAN.md`
writes (ADR-0032).

Use `/goal <measurable done condition, validation command, constraints, stop
limit>` for till-done loops. Pi and Claude orchestration parity lives in
[`../workflow/skills/orchestration.md`](../workflow/skills/orchestration.md);
Task* state is Pi-only.

Sync supports optional `env.CLAUDE_CODE_SUBAGENT_MODEL` (for example `sonnet`).
It stays unset in the shared fragment until all runtimes (including SDK/IDE CLIs) are verified.
An explicitly tracked key overwrites its local value; other local `env` keys and
values are preserved without logging. On Claude Code >=2.1.251, this is a default for
subagents with no explicit model: per-call model and agent frontmatter
(including `inherit`) take precedence. Explicit Opus adversaries remain Opus.
`CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is not managed; if set by the user, native
forced-model behavior still applies. Older Claude versions gave the default
env key higher precedence; upgrade before using this policy. See the
[native model resolution order](https://code.claude.com/docs/en/sub-agents#choose-a-model).
The PATH version probe is a partial check, not certification of other runtimes.
Sync probes `claude --version` on PATH (5 s cap). On an old, missing or
unrecognized runtime, it warns and skips only the managed env key; other
tracked settings still sync. Existing local env values remain untouched.
Council launchers exclude user settings but do not scrub an inherited process
env: a model-less descendant can receive this default from a Claude caller.
Explicit reviewer models, effort and turn limits stay unchanged. Plugin
`model: inherit` remains explicit. No measured token saving is established.

## PR autoreview

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
- A later push is reviewed on the commits since the last reviewed head (the
  full diff after a rebase or a new base), and posts nothing when it finds
  nothing.

`pr-autoreview/install.sh` wires a machine.

## PR review watch

`scopes/work/scripts/pr-review-watch/` reviews PRs where your review is
requested, never your own. A LaunchAgent runs `watch.sh` every 60 s by default.
It watches open PRs until they are closed, approved or no longer involve you,
and reviews a head sha 120 s after it first sees that sha. It skips PRs with
more than 5000 changed lines outside lockfiles, runs at most 2 reviews at once
and 20 a day, and makes at most 3 attempts per head. Each review opens in a `pr-reviews` herdr tab, or runs
detached.

### What a review does

The first review is `/pr-council-review --post`. It also reads open PRs linked
to this one in the owner's repositories, and turns a finding one of them
already fixes into a merge-order note. Later pushes get `/code-review` on the
new commits, then the machine-local fix-verification skill
(`PR_COUNCIL_VERIFY_SKILL`, else the first line of
`~/.config/pr-council-review/verify-skill`). Without one, that step is marked
unconfigured and the head stays due. A head whose full review found nothing,
with no review of yours on the PR, skips the step and needs no verify skill.
Later pushes read the linked PRs too.

The watch approves only when the model is confident and its own checks hold:
head unchanged, PR open and not draft, no unresolved thread, no other changes
requested, CI green. Agent config files a PR changes are reset to base in every
scratch worktree. A Claude pass silent for 900 s is stopped and retried like
one that hits the 2700 s cap.

- State: `~/.claude/state/pr-review-watch/`.
- Logs: `~/.claude/logs/pr-review-watch.log` and `pr-review-usage.log`.
- `watch.sh stop` sets the kill switch and stops reviews in flight.
- `tests/pr-review-gates-smoke.sh` covers the approval gates.

### Settle, polling and timing

The settle clock starts when the watch first sees a head sha, not at the push
time. Polling rounds the wait up to a later tick, and launchd scheduling, queue
caps and review runtime can delay it further. At the default 60 s interval,
snapshot lookups alone come to about 60 per watched PR per hour, plus
discovery and size lookups. That counts calls, not GitHub API points.

`PR_REVIEW_WATCH_SETTLE` overrides the settle delay for a direct run. The
LaunchAgent sets only PATH, so a shell export does not reach its job: put a
settle override in the plist's `EnvironmentVariables`.
`pr-review-watch/install.sh <seconds>` sets the polling interval, and an
installed plist keeps its interval until you rerun it. The scripts are linked
to the checkout, so an edit there applies on the next run.

Each pass writes a timing line to stderr and `pr-review-usage.log`:
`timing <pass>: elapsed_s=<integer> process_exit=<code>`. Codex passes share
one `codex` label, so correlate them with the target and run report. Phase A
runs its passes in parallel, so the sum of pass times is not the council
latency.
`process_exit=0` means only that the CLI exited cleanly. Completion,
permission checks and approval gates still decide the result. A signal that
kills the shell can leave no timing line, so drop incomplete samples instead
of counting them as zero.

### Incomplete councils and stored reports

A council with a pending lens, ticketed security or a malformed run marker is
incomplete even when it posted findings. It records no completed council: the
current sha stops with exit 4, and a new push gets a full council until that
state is resolved. That costs more than the ordinary fix-verification path.

Before it reuses a completed council or retries an approval, the runner
validates the stored council report against the full sha. Missing,
incomplete or inconsistent state gets a full council under the normal caps,
and an invalid pending approval is requeued on the next tick. Reports expire
after 30 days, so an older PR can need another full review.

A report counts only when it meets these rules
(`pr-council-review/lib.sh`):

- exactly one phase-B header; extra header-like text, or a PR title starting
  with `phase B: `, makes it incomplete;
- run markers are whole lines starting with `<!-- claudine:v1 ` or
  `=== run marker: claudine:v1 `, so inline and blockquoted copies do not
  count;
- each marker holds exactly one JSON object with no duplicate key, and counts
  only when its `kind` is `run` and its `sha` is the full head sha;
- every matching marker must be complete, and the highest finding count wins;
- `lenses` is a non-empty array or object of strings, with no `pending` lens;
- `security` is a non-blank string, and `ticketed` in any letter case is
  refused;
- `findings` is a non-negative integer.

These are the consumer's rules. Whether the external validator's reports
meet them has not been checked against a real report yet, so check one before
you rely on the validator path. `run marker has no lenses` in the log points
to a producer that does not emit lenses.

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
