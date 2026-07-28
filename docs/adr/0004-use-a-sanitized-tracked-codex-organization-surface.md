---
status: superseded by ADR-0011
date: 2026-06-12
tags: [codex, deployment, security]
affected_components: [codex, scripts/deploy-codex]
superseded_by: ADR-0011
---


# Use a sanitized tracked Codex organization surface

Etabli tracks a sanitized Codex organization under codex/ and deploys it with scripts/deploy-codex instead of versioning live ~/.codex state. This rejects direct sync of local Codex config because live provider credentials, trust state, and thread artifacts must stay local while shared prompts, hooks, skills, and workflow contracts remain reviewable.

Superseded by ADR-0011.
