---
status: accepted
date: 2026-08-07
tags: [harness, codex, skills, vendor, install]
affected_components: [scripts/lib/install-main.sh, vendor, workflow/runtime/skill-surface.tsv, docs/adr/0011]
---

# Treat ~/.codex/skills as a managed link surface without restoring the Codex harness

The installer now links vendored skills into `~/.codex/skills` alongside
`~/.claude/skills` and `~/.pi/agent/skills`. Skills are the only Codex surface
Etabli manages: no `codex/` tree, no `scripts/deploy-codex`, no per-harness
organization docs or CI smokes come back.

ADR-0011 removed the Codex harness because maintaining per-harness trees, deploy
scripts and pinned docs "for harnesses with no live local install cost more than
the optionality it preserved". That premise no longer holds on this machine —
`codex-cli` 0.147.0 is installed and in use. What ADR-0011 actually deleted were
*duplicated authoring surfaces*; a symlink into a harness that is running is not
one. The distinction is the whole decision: authoring stays single-sourced in
`pi/skills/`, `claude/scopes/` and `vendor/`, while linking fans that one source
out to whatever harness is present.

The cost of leaving it undecided was concrete. Because no ADR covered the Codex
skill surface, `~/.codex/skills` drifted unnoticed into 39 directories whose
`SKILL.md` was a dead symlink into the deleted `etabli/codex/skills/`, including
AdonisJS and TanStack Start sets that were advertised to the agent while holding
no content at all.

## Considered Options

- **Link skills into `~/.codex/skills` (chosen).** One authored source, fanned
  out to every installed harness. Costs a third link target in the installer.
- **Leave Codex unmanaged.** Cheapest, but a running harness keeps reading a
  directory nobody owns, which is exactly how the 39 dead shells appeared.
- **Restore the full Codex harness surface.** Rejected for the reason ADR-0011
  gave: per-harness authoring trees and deploy scripts are the expensive part,
  and nothing here needs them.
- **Delete `~/.codex/skills` entirely.** Rejected: it removes capability from a
  harness the user actively runs, to satisfy a decision aimed at a different
  problem.

## Consequences

- Good, because one authored skill reaches Claude, Pi and Codex from a single
  source, with the deploy scope still decided by `~/.etabli-scope`.
- Good, because the surface is now owned, so drift is a bug with a home rather
  than an unclaimed directory.
- Bad, because a fourth harness would need its own link block; the installer
  gains a target per harness rather than discovering them.
- ADR-0011 stands. Its harness removal is unchanged and this ADR does not
  supersede it: it records that the *skill link surface* was never what ADR-0011
  set out to delete.
