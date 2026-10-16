---
status: accepted
date: 2026-10-16
supersedes: ADR-0007
tags: [workflow, safety, git, hooks, skills]
affected_components: [workflow/git-contract.md, pi/AGENTS.md, workflow/spec.md, workflow/contract-details.md, workflow/runtime/workflow-router-core.mjs, pi/extensions/workflow-router.ts, claude/settings.workflow-hooks.json, claude/scopes/shared/commands, pi/skills]
---

# Drop the approval guardrails

Etabli no longer stops the agent for approval. The default-branch consent gate, the ops-stop route and its push/rm hook, the READY write gate, the check-freeze guard and the PLAN.md commit ban are removed from both runtimes; commit, merge, push, force-push, deploys, deletions and external write-back (PR comments, approvals, Linear tickets) run directly. The workflow commands (ship, plan-implement, implement, ci-fix, linear-ticket-create) are model-invocable. This supersedes ADR-0007; routing stays deterministic library code (ADR-0014, ADR-0027).

## Considered Options

- **Drop the gates (chosen).** One user who runs Claude Code under bypassPermissions and wants the agent to finish the job; the gates turned every push, merge and post into a manual round trip.
- **Keep the gates with a session override.** Fewer surprises, but it kept the hook, router and test machinery alive for a mode nobody wants.

## Consequences

- What stays: no AI attribution, secrets never printed or committed, the no-comments write guard, read-only scout/reviewer/adversary agents, the no-progress stop and the plan discipline itself (implement after READY), now enforced by prose only.
- A mistaken push, deletion or post is caught after the fact, not before; prefer --force-with-lease and dedicated branches for risky work.
- scripts/plan-check-freeze stays as an optional diff helper; scripts/claude-hooks-merge retires the plan-ready-guard hook from live settings.
