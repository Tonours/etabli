---
status: accepted
date: 2026-11-13
tags: [workflow, simplification, skills, hooks]
affected_components: [claude/settings.workflow-hooks.json, scripts/claude-hooks-fragment.mjs, workflow/spec.md, workflow/runtime/skill-surface.tsv, vendor/sources.tsv, workflow/runtime/pr-body-guard.mjs, scripts/deploy-workflow, tests/entry-chain-budget-smoke.sh]
---

# Prune the surfaces the census shows unused

A 28-day transcript census counted, per session, the skills, slash commands
and contract reads of Claude, Pi and Codex: 2 349 session files on macmini and
2 696 on macbook-work (counts only, no content copied). Unlike the mention
census of ADR-0042, it counts sessions that invoked or read a surface, so it
separates real use from injected file lists. Applying the ADR-0035 weekly-use
bar, this change deletes:

- RTK: the `rtk-guard` hook, the Pi `rtk` extension and runtime, `RTK.md` and
  the installer step. Measured savings were 1.8 % of tokens in November, while
  its prefixes cost a rule in every prompt and a bypass list in the hook
  checks. `rtk-guard.mjs` joins the retired hook names, so
  `claude-hooks-merge` removes the installed entry.
- Cold contracts, read in at most a couple of sessions: `contract-details.md`,
  `memory.md`, `project-constraints.md`, `verification-report-template.md`,
  the evidence-pack schema and template, and the `long-loop`,
  `execution-quality` and `verify` skills. Their few live rules move into
  `workflow/spec.md` golden principles or the consuming contract. All join
  `RETIRED_FILES`, so `deploy-workflow --prune` removes scaffolded copies.
- Skills used 0-2 times in 28 days on both machines: `bug-check`,
  `linear-work`, `linear-project-setup`, `verify-workflow`, `spec`; vendored
  `domain-modeling`, `grill-with-docs`, `improve-codebase-architecture`,
  `prototype`, `wizard`, `no-ai-slop`, `typesafe-ai`; shelved `coolify` and
  `react-doctor-100`. The `verify` route folds into `answer`.
- `scripts/prs-today` and its smoke.

Two behaviours change instead of being deleted. `pr-body-guard` lets a PR body
it cannot read (built at run time, piped, missing, unreadable, or a relative
file behind an unresolved `cd`) through for that invocation, and keeps
checking the other invocations and commits of the line. The census found
these refusals on bodies the agent had just written correctly, so they cost
retries without catching a bad body. The
Pi Task* fact is stated once in `workflow/skills/orchestration.md`.

The entry chain is now `AGENTS.md`, `workflow/spec.md` and
`workflow/agent-rules.md` at 317 lines; the budget cap drops from 405 to 330.

Census findings refuted during recon and kept: `thermo-nuclear-code-quality-review`
(loaded by the council), `apply-adr` (lives in the shared `adr` skill),
`pi-dmi-stamp` (installer step), the Cursor runner, the PLAN hash ritual
(identifies the reviewed snapshot) and evidence labels (archives are read
back).

## Consequences

- Each machine runs `claude-hooks-merge` before the hook file disappears, then
  `deploy-agent-workflow --apply` after merge; running Pi sessions keep the
  old extension until restarted.
- A dropped skill comes back from git history (`vendor/README.md` § Restore a
  dropped pack for vendored ones).
- Review date: 2027-02-13. Rerun the census; restore a skill only if its
  absence was asked for at least weekly.
