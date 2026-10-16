---
status: accepted
date: 2026-10-16
supersedes: [ADR-0015, ADR-0024]
tags: [harness, skills, install, claude, pi]
affected_components: [scripts/deploy-agent-workflow, scripts/lib/managed-surfaces.sh, scripts/check-fix-symlinks.sh, workflow/runtime/skill-surface.tsv, claude/mods, docs/adr/0011, docs/adr/0015, docs/adr/0024]
---

# Manage only the Pi and Claude surfaces

Etabli deploys skills, workflow links and the /etabli cockpit to Claude Code and Pi only. The ~/.codex/skills, ~/.config/devin/skills and shared ~/.agents surfaces are no longer fed: deploy-agent-workflow prunes this checkout's own links there and leaves real directories and foreign links alone, and the agents_visible catalog column is gone. This supersedes ADR-0015 and ADR-0024, and amends the ADR-0011 clause that kept ~/.agents for Grok and future harnesses. Convergence stays behind deploy-agent-workflow (ADR-0018) and the routed core is unchanged (ADR-0027).

## Considered Options

- **Pi and Claude only (chosen).** One user, two harnesses in daily use; every other surface carried smokes, catalog columns and adapter fallbacks for runtimes nobody launched.
- **Keep ~/.agents as a neutral shared surface.** Cheap to keep, but it stayed the reason for agents_visible, three fallback paths in every adapter and the Codex and Devin link blocks.

## Consequences

- Pi still loads ~/.agents/skills natively, so pi-skill-load-check and pi-dmi-stamp keep reading it to measure Pi's prompt; they deploy nothing there.
- Codex stays available as a model provider for adversary passes; only its skill surface is retired.
- A new harness needs a new ADR and its own deploy block.
- The /etabli plugin is installed through the etabli-local folder marketplace in claude/mods, read from the checkout.
