---
status: accepted
date: 2026-06-25
tags: [workflow, routing, safety]
affected_components: [claude/hooks, pi/extensions/lib/workflow-router-runtime.ts, tests/fixtures/claude-hooks]
---

# Gate workflow routing with deterministic guards

Etabli routes workflow prompts through deterministic router libraries, hooks, fixtures, and READY guards before agent-specific commands proceed. This accepts maintenance of runtime predicates and smoke fixtures because hard safety boundaries such as read-only review, ops-stop, and READY enforcement cannot depend only on prompt wording.
