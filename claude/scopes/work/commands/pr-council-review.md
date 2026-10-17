---
description: Runs a three-pass review of one PR (code-review + thermo-nuclear, then forest:validator as the council), dry-run by default. Use when a GitHub PR needs the full council review; not for local diffs (review).
argument-hint: "<PR number or URL> [owner/repo] [--post] [--codex] [--phase-a-model <alias>]"
allowed-tools: [Bash, Read, Glob, Grep]
---

Run `~/.claude/scripts/pr-council-review/run.sh $ARGUMENTS` from the repository
the PR belongs to, and stream its output.

The script does the orchestration; you do not re-run any of the passes yourself.

It needs the `thermo-nuclear-code-quality-review` skill installed for Pi
(`~/.pi/agent/skills/`) and stops without it. It
refuses a closed or merged PR. Agent config files the PR changes are reset to
the base version in the scratch worktree, so the PR cannot steer phase A. Token
usage per pass is appended to `~/.claude/logs/pr-review-usage.log`.

- Phase A, in a detached scratch worktree at the PR head: `/code-review` and
  `/thermo-nuclear-code-quality-review` in parallel. Neither writes to GitHub.
  Phase A runs on `sonnet` (`--phase-a-model` / `PR_COUNCIL_PHASE_A_MODEL`)
  without MCP servers, hooks or user settings, to keep each session's base
  context small; the validator keeps the full setup on `opus`.
  Claude-only by default; a third `codex` pass runs only with `--codex`, so
  report a plain run as a same-family review, never as cross-model.
- Phase B: `/validator` on the PR, with phase A's findings injected as extra
  candidates for its step 6 skeptic gate. One review, the validator's emit
  contract, its writing rules, its markers.

Without `--post` the validator prints the review payload it would submit and
writes nothing to GitHub. Pass `--post` whenever the request is to publish the
review; no separate confirmation.

When the script exits, report: the PR, what each phase found, how many phase A
candidates survived the skeptic gate, whether anything was posted, and the path
to the kept reports. Do not restate the full reports; they already went to
stdout.
