---
status: accepted
date: 2026-10-16
supersedes: [ADR-0019]
tags: [tooling, simplification, hooks, review, pi, claude]
affected_components: [scripts/pi-review-hunter, claude/settings.workflow-hooks.json, pi/extensions/workflow-router.ts, scripts/deploy-agent-workflow, scripts/claude-skill-load-check, workflow/runtime/agentic-infra-checks.tsv]
---

# Strip Etabli to the tooling in daily use

A 60-day transcript census (Claude, Pi and Codex on the laptop and macbook-work) showed that outside the Etabli repo itself only the plan loop, plan-cleanup, workflow-event, plan-review-check, the review hunters and the shared rule texts are used. Everything that mostly served Etabli's own maintenance goes:

- ledger validation (`workflow-run-check`, `workflow-ledger-check`, rule registry, source ownership, lineage, durable-exports and events-validator docs); `ledger-integrity` stays because plan-review-check needs it;
- answer-quality tooling (check, eval, traces, claim-evidence, research-proof); `workflow/answer-quality.md` stays as a rule;
- review receipts (`review-hunter-capture`, `review-evidence-pack`, receipts, prompt observers); `pi-review-hunter` now runs `pi --mode text -p` directly with a timeout;
- router-eval and router-parity; the golden fixtures in `tests/router-evals/core.json` stay for the router tests;
- the Claude `/etabli` cockpit and its `etabli-local` marketplace, the session-handoff/session-state hook, the correction, notification, ADR-signal and ledger auto-emit hooks (Claude and Pi), and the `claude-*` launchers with the lean profile (the skill load check now always checks the full surface);
- the Pi extensions pi-mobile-bridge, token-rate, session-hygiene and filter-output;
- small dead tools (pi-dmi-probe, graph-neighborhood, obvault-shadow-promote, worker-recovery, scaffold-project, week-roadmap, employer-mfe-qa, spec-guide), the context-budget and ref-linter meta-checks, and dated archives, audits and traces (Git history keeps them).

## Consequences

- Claude hooks are only the no-comments, rtk and read-only-agent guards; the removed hook commands are listed as retired so `claude-hooks-merge` unwires them.
- ADR-0019's measurement premise no longer has tooling; this supersedes it.
