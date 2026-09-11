---
status: accepted
date: 2026-09-10
tags: [harness, devin, skills, vendor, install]
affected_components: [scripts/lib/install-main.sh, scripts/deploy-agent-workflow, scripts/check-fix-symlinks.sh, docs/adr/0015]
---

# Treat ~/.config/devin/skills as a managed link surface

Devin CLI is installed and running on this machine. It discovers global skills from `~/.agents/skills` (the shared agents-visible surface) and from its own canonical `~/.config/devin/skills`. Etabli now manages the Devin surface the same way ADR-0015 managed Codex: active-scope vendored skills and the herdr skill are linked in, Pi-authored skills stay on the Pi and agents surfaces, and a `pi/skills` link on the Devin surface is drift that deploy and fix-links remove.

Relying on the shared `~/.agents/skills` surface alone would leave Devin with only the `agents_visible` catalog subset and no owned home for vendored suite links - the same unowned-directory drift ADR-0015 recorded for Codex.

## Considered Options

- **Link vendored skills into `~/.config/devin/skills` (chosen).** Canonical documented location, parity with the Codex surface, one more link target per vendored skill.
- **Rely on `~/.agents/skills` only.** Cheapest, but caps Devin at the agents_visible subset and leaves the canonical directory unowned.
- **Deploy the full Claude scoped set.** Rejected: scoped Claude skills are Claude-surface policy, not vendored; Codex parity keeps the model simple.

## Consequences

- Good, because Devin sees the same vendored suite as Claude and Codex plus the agents_visible Pi skills through `~/.agents/skills`.
- Good, because the surface is owned: stale or out-of-scope links are pruned by the same machinery as the other surfaces.
- Neutral, because a fifth harness would again need its own link block.
