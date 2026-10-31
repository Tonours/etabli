# Implemented: Agent friction from three days of work-MacBook sessions

## Metadata
- Archived: 2026-10-31
- Source plan: fleet QOL list, wave G (points 46-55), from a corpus of the work MacBook's Claude and Pi sessions and logs, 2026-10-27 to 2026-10-30
- Status: IMPLEMENTED
- Commit / branch: `fix/qol-agent-friction`, based on `da738bab`
- Workflow initiative: fleet-qol

## Outcome
- PR autoreview (46): one review per push, about 45 in three days, 12 on one
  PR, almost all without a finding, each posted to Slack. A later push is now
  reviewed on the commits since the last reviewed head against the same base
  (`~/.claude/state/pr-autoreview-heads`), the full diff after a rebase or a
  new base, and posts nothing when it finds nothing. The base is read again
  with the head once the lock is held.
- Council relaunch (48): an agent guessed the retired
  `claude/scopes/work/commands/` path to relaunch a round. The skill now says
  to rerun the same command and where the script lives.
- no-comments guard (49): agents retried with `SAFETY:` prefixes. The deny text
  says any prefix is refused and where the reason goes instead.
- Agent rules (50, 51): BSD `sed` on macOS; a `workflow/...` file missing from
  the current directory is read under `~/.claude/workflow/` or
  `~/.pi/agent/workflow/` (a scaffolded project's local copy still wins).
- Memory (54, 55): Datadog MCP pitfalls and the Swan production 403 are staged
  as brain captures.

## Not changed
- 47: the one "Not logged in" was a transient auth failure of the fleet daemon's
  Linear triage; its retry succeeded 9 s later.
- 52: the auto-mode classifier denials came from the chief rebasing and
  force-pushing in its own scratchpad and writing to GitHub; they are the
  intended guard, so no allow rule.
- 53: no evidence of an MCP tool failing to read a file.

## Checks
- `bash tests/pr-review-flow-smoke.sh`: ok, with three new autoreview checks
  (no prior head, last head of this PR only, a new base reviews the full diff).
- Mutation probes: matching the key by substring, and ignoring the base, each
  fail one new check.
- `scripts/verify-agentic-infra all`: 43/43 passed.
- Cross-model adversary (codex `gpt-6.1-sol`): round 1 BLOCK (retarget, local
  workflow precedence), round 2 BLOCK (base stale after the lock wait), all
  fixed.
