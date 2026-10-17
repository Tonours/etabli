---
status: accepted
date: 2026-10-17
supersedes: ADR-0014
tags: [workflow, routing, simplification]
affected_components: [workflow/runtime, pi/extensions, claude/hooks, scripts/verify-agentic-infra, tests]
---

# Drop the route classifier and its orphan telemetry

Etabli no longer ships an executable route classifier: since ADR-0014 removed prompt injection and ADR-0032 removed the guards it fed, its only output was an `appendEntry` record in Pi sessions that nothing read, so the model now routes from the table in `workflow/spec.md` alone. The classifier, its obvault topic resolver, golden fixtures and scenario suites go with it, as do the write-only guard journal, the stale live-agent profile, the runtime capability matrix and the adapter-sync header stamp; the read-only Bash policy the read-only agents depend on survives as `workflow/runtime/read-only-bash.mjs`.
