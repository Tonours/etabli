---
status: accepted
date: 2026-06-29
tags: [adr, documentation, validation]
affected_components: [claude/skills/adr, scripts/validate-adrs, docs/adr]
---

# Record ADRs through a deterministic helper and validator

Etabli records architecture decisions through the Claude /adr skill, but all file writes, numbering, supersession updates, and CLAUDE.md index mutations go through claude/skills/adr/scripts/apply-adr.mjs and scripts/validate-adrs. This rejects hand-edited ADR state because immutable records and supersession links need deterministic rollback and validation even though the skill still supplies the human decision context.
