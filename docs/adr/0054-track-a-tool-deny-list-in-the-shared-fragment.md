---
status: accepted
date: 2026-11-24
tags: [settings, tokens, deploy]
affected_components: [claude/settings.skill-overrides.json, scripts/lib/claude-settings-sync.mjs, claude/README.md]
---

# Track a tool deny list in the shared fragment

The tracked fragment now carries `permissions.deny` with six entries:
`Artifact`, `SendFeedback`, `ShareOnboardingGuide`, `Agent(Explore)`,
`Agent(Plan)` and `Agent(statusline-setup)`. A bare tool name in `deny`
removes the tool's schema from the context, and `Agent(<type>)` removes the
type from the agent listing. Every session that reads the user settings
stops carrying them: interactive `cli`, Fleet threads (their own
`--settings` deny merges with it) and T3 Code sessions.

The writer admits `deny` and nothing else new under `permissions`. Each
tracked entry must belong to a fixed allowlist in
`scripts/lib/claude-settings-sync.mjs`, one line per entry like
`ENV_KEYS`, and the list must be a non-empty array without repeats; a
fragment that breaks a rule is refused before any backup or write. The
merge is a union: local entries keep their place, missing tracked entries
are appended, other local `permissions` keys stay, and `--check` reports
drift only while a tracked entry is missing. A local `permissions` that is
not an object, or a local `deny` that is not an array of strings, is
refused before the backup instead of being spread.

Context. The 7-day audit of 24 November 2026 (`j_carriedVsUsed`, ADR-0050)
ran on four complete Claude roots over gromarchy, macbook-work and macmini.
Each entry had zero used sessions on every root, `Artifact` included: no
use in that window, one in 558 Mac sessions in the planning count, for a
schema of about 58k chars on its own. A `cli` session on the Mac started
with about 76k tokens before the first user word.

Rejected options:
- Shape validation alone (any string allowed): one slip in the fragment
  could deny `Bash` on every host.
- A version gate: an unknown name in `deny` is inert on every version in
  use (2.1.292 to 2.1.331), so a probe would add a path with no behavior.
- Removing local entries struck from the fragment: it breaks the README
  rule that a key removed from the fragment keeps its local value, and the
  file has no notion of which entry the fragment owns.
- `--disallowedTools` in each harness: one tracked list reaches every
  session that reads the user settings. The isolated review launchers
  skip those settings, so this list does not reach them; they need their
  own `--disallowedTools` value, a separate change.

Rollback: revert the fragment entry and, on each host, delete the entry
from `permissions.deny` in `~/.claude/settings.json` or restore the
writer's backup.

- Review date: 2026-12-08. The whole list is deleted if an entry had to be
  struck to get work done, or if the 7-day audit shows a `cli` first-turn
  drop under 12k tokens.
