---
name: pr-council-review
description: Runs a cross-family review of one PR (code-review + thermo-nuclear + codex, then forest:validator as the council), dry-run by default. Use when a GitHub PR needs the full council review; not for local diffs (review).
argument-hint: "<PR number or URL> [owner/repo] [--post] [--phase-a-model <alias>] [--no-codex] [--codex-model <model>]"
allowed-tools: [Bash, Read, Glob, Grep]
---

Run `~/.claude/scripts/pr-council-review/run.sh $ARGUMENTS` from the repository
the PR belongs to, and stream its output.

The script does the orchestration; you do not re-run any of the passes yourself.

It needs the `thermo-nuclear-code-quality-review` skill on the Claude or Pi
skill surface and stops without it. It
refuses a closed or merged PR. Agent config files the PR changes are reset to
the base version in the scratch worktree, so the PR cannot steer phase A. Token
usage per pass is appended to `~/.claude/logs/pr-review-usage.log`.

- Phase A, in a detached scratch worktree at the PR head: `/code-review`,
  `/thermo-nuclear-code-quality-review` and a `codex exec` review in parallel.
  None writes to GitHub.
  Phase A runs on `sonnet` (`--phase-a-model` / `PR_COUNCIL_PHASE_A_MODEL`)
  without MCP servers, hooks or user settings, to keep each session's base
  context small; the validator keeps the full setup on `opus`.
  The codex member runs `gpt-6.1-sol` at `xhigh` (`--codex-model`,
  `--codex-effort`, `PR_COUNCIL_CODEX_*`) in a read-only sandbox without user
  config; `--no-codex` or `PR_COUNCIL_USE_CODEX=0` skips it. Report the run as
  cross-family only when the codex pass succeeded; a missing binary or a failed
  pass leaves a same-family review.
- Phase B: `/validator` on the PR, with phase A's findings injected as extra
  candidates for its step 6 skeptic gate. One review, the validator's emit
  contract, its writing rules, its markers.

Validator already on this head: the validator refuses a SHA it already
reviewed. When the validator's login (`PR_COUNCIL_VALIDATOR_LOGIN`, else the
machine-local `~/.config/pr-council-review/validator-login`) has a completed
review on the current head SHA, the script runs phase A only, every pass on
`opus` at `high` (`--with-validator` forces the validator, `--phase-a-only`
forces this mode, `PR_COUNCIL_PHASE_A_ONLY=auto|0|1`). With no login
configured, `auto` keeps the validator and `--phase-a-only` exits 2. An opus
pass verifies phase A's findings against the code and, with `--post`, posts
one `COMMENT` review (changed lines inline, the rest in the body), or nothing
when none survive. It never approves: it ends with the validator's run marker.
The script reads the head's reviews again after that pass: when the
validator's latest review is not an approval, it appends a marker counting it
as open, and when findings were kept under `--post` but no new review of ours
is on the head, it exits 1 so the watcher retries. The watcher approves only
behind its gates and only when nothing stands; a validator approval on the head
is taken as its completion.

A permission denial in any pass is a veto: the validator does not run or its
review is not approved, and the script exits 3. A session that ends incomplete
(an error, a turn or budget cap) exits 4; the watcher also counts a validator run
without its run marker as incomplete, and retries neither on the same head.

Without `--post` the validator prints the review payload it would submit and
writes nothing to GitHub. Pass `--post` whenever the request is to publish the
review; no separate confirmation.

When the script exits, report: the PR, what each phase found, how many phase A
candidates survived the skeptic gate, whether anything was posted, and the path
to the kept reports. Do not restate the full reports; they already went to
stdout.
