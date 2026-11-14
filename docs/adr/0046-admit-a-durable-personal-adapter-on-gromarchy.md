---
status: accepted
date: 2026-11-15
tags: [durable, harness, planning]
affected_components: [durable, workflow, AGENTS.md]
---

# Admit a durable personal adapter on gromarchy

Admit a tracked durable/ adapter: one systemd user daemon on gromarchy owns a pi-durable store and one conversation/worktree per run, so work can survive crashes and be steered remotely. The owner chooses this native loop over phase-level CLI recovery and a separate adapter over extending interactive Pi; shared rules, guards, review templates and model routes remain canonical under workflow/. This accepts maintenance before weekly-use measurement, without a review-date deletion requirement for this adapter.

## Scoped amendments

- ADR-0002: only durable runs use an EtabliPlanDoc in SQLite instead of PLAN.md; statuses, gates and evidence remain, with immutable final snapshots instead of docs/plan/ files and CLI access to the document.
- ADR-0006: durable is another thin adapter, not another workflow copy.
- ADR-0029: durable selects native openai-codex Sol, Astra escalation, then native Z.ai GLM on READY; interactive defaults stay separate. Technical OAuth support does not establish subscription terms coverage.
- ADR-0031: admit this personal gromarchy adapter alongside the managed interactive runtimes. No Fleet, work-org repository or Linear integration is added.

## Operating boundaries

- Require personal scope and allow only repositories owned by Tonours or tonours-dev. The existing gh token still reaches work organizations; direct invocation controls can be bypassed through arbitrary Bash or API use and provide no security separation. No kernel sandbox is planned in v1.
- Start with at most two active runs, four hours plus a turn cap each. Stop on blocked or after push, PR creation and notification; the daemon never merges.
- Share Pi credentials only after the concurrent-refresh proof passes; otherwise use a separate credential store and login. Never put credentials in conversation documents.
- Reviewers exclude every author family under author_family_routes, prefer eligible native routes and use the Claude CLI fallback when needed; no eligible route blocks review.
- Pin pi-durable and its planned companion packages to 1.5.2. Upgrades require a dedicated PR, a store backup, no active run and a passing kill/resume suite. Keep 14 daily local backups.
- Remote HTTP/WebSocket access requires both bearer token and allowed tailnet identity; the local CLI uses a separate Unix socket. TUI, PWA, triggers, subagents and MCP follow in later slices.
