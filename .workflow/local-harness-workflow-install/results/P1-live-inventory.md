# P1 Live Inventory

## Result

- Codex had 359 same-content regular-file copies, 10 repo symlinks, 3 missing
  tracked files, and 0 divergent files before relink.
- Claude and Pi core workflow links already existed for the main guidance files.
- Pi live `~/.pi/agent/settings.json` kept scoped `@tintinweb` packages as
  strings, not as the tracked package objects.
- `~/.claude/commands/commit.md` was an older local copy of the tracked command.

## Decision

- Relink same-content Codex copies to repo symlinks.
- Sync only managed Pi package entries while preserving unknown local packages.
- Back up Claude `commit.md` before replacing it with a symlink.
