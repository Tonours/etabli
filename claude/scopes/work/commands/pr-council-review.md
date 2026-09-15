---
description: Three-pass review of one PR (code-review + thermo-nuclear, then forest:validator as the council) with a dry-run by default
argument-hint: "<PR number or URL> [owner/repo] [--post] [--codex]"
allowed-tools: [Bash, Read, Glob, Grep]
---

Run `~/.claude/scripts/pr-council-review/run.sh $ARGUMENTS` from the repository
the PR belongs to, and stream its output.

The script does the orchestration; you do not re-run any of the passes yourself.

- Phase A, in a detached scratch worktree at the PR head: `/code-review` and
  `/thermo-nuclear-code-quality-review` in parallel. Neither writes to GitHub.
  Claude-only by default; a third `codex` pass runs only with `--codex`, so
  report a plain run as a same-family review, never as cross-model.
- Phase B: `/validator` on the PR, with phase A's findings injected as extra
  candidates for its step 6 skeptic gate. One review, the validator's emit
  contract, its writing rules, its markers.

Without `--post` the validator prints the review payload it would submit and
writes nothing to GitHub. Pass `--post` only when the user asked for it in the
message that invoked this command — a review is public the moment it lands.

When the script exits, report: the PR, what each phase found, how many phase A
candidates survived the skeptic gate, whether anything was posted, and the path
to the kept reports. Do not restate the full reports; they already went to
stdout.
