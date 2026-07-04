---
status: accepted
date: 2026-06-15
tags: [multi-agent, workflow, dedupe]
affected_components: [workflow/skills, pi/skills, claude/commands, codex/skills]
---

# Keep agent surfaces as adapters over shared workflow contracts

Etabli keeps agent-specific commands and skills thin while shared behavior lives under workflow/ and workflow/skills/. This rejects independent Pi, Claude, and Codex workflow copies because cross-agent parity, smoke tests, and cleanup are more valuable than local surface autonomy, at the cost of adapter indirection.
