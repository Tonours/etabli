# P2/P3 Local Deploy

## Applied

- Added `scripts/deploy-agent-workflow` as a focused local deployer for Codex,
  Claude Code, and Pi workflow surfaces.
- Added `--prefer-links` to `scripts/deploy-codex` so identical live copies can
  be relinked to tracked repo files.
- Ran `scripts/deploy-agent-workflow --apply`.

## Evidence

- Codex: `SUMMARY 362 linked, 10 unchanged`.
- Pi: `~/.pi/agent/settings.json` backed up to
  `/Users/tonours/.pi/agent/settings.json.bak.20260703-090415`.
- Pi: synced `local:etabli-workflow`, `npm:@tintinweb/pi-subagents`, and
  `npm:@tintinweb/pi-tasks`.
- Claude: `~/.claude/commands/commit.md` backed up to
  `/Users/tonours/.claude/commands/commit.md.bak.20260703-090415`.
- Claude: linked missing commands, hooks, and skills from the tracked repo.
