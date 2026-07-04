---
status: accepted
date: 2026-03-30
tags: [workflow, planning]
affected_components: [PLAN_TEMPLATE.md, workflow/spec.md, pi/skills, claude/commands]
---

# Use PLAN.md as the single active execution artifact

Etabli uses a root PLAN.md with explicit statuses as the only active execution artifact; implementation is allowed only from Status: READY and completed work is archived elsewhere. This rejects scattered active plans across commands and skills because deterministic review, handoff, and validation gates need one mutable source of truth even though it adds plan upkeep overhead.
