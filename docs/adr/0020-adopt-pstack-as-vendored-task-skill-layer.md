---
status: accepted
date: 2026-08-28
tags: [tooling, skills, vendor, pstack]
affected_components: [vendor/sources.tsv, scripts/sync-vendor-skills, workflow/runtime/skill-surface.tsv, docs/pstack-strategy.md]
---

# Adopt pstack as a vendored task-skill layer, not a workflow replacement

## Context

A session asked whether etabli should be dropped in favor of pstack (Lauren
Tan's Cursor plugin: 23 workflow skills, 21 principles, 22 playbooks). The
analysis found the overlap is real but partial: pstack covers the task-skill
layer (investigation, review, verification playbooks) that etabli's
`workflow/` routes approximate, while etabli's remaining layers — multi-runtime
deployment, scope system, obvault memory, Linear, herdr multihost, editor
configs, the PLAN.md gate — have no pstack equivalent. pstack is Cursor-first
(subagent model assignment, `/loop`, plugin install); Pi is this repo's
primary runtime. A community `pi-pstack` port exists but is unvetted
(0-star). ADR-0013 already removed the multi-model council from etabli's own
review route; pstack's multi-model behavior is opt-in at task level, a
different layer than route wiring.

## Decision

Vendor eight runtime-agnostic, non-overlapping pstack skills
(`how`, `why`, `architect`, `blast-radius`, `tdd`, `interrogate`,
`create-verification-skill`, `maintain-verification-skill`) from
`cursor/plugins` @ `main` through the existing vendor mechanism, extended with
an optional `subpath` manifest column since the monorepo keeps pstack at
`plugins/pstack` rather than the repo root. Deploy via catalog rows
`source=pstack` (`0 0 1`): the install vendor loop links them into
`~/.pi/agent/skills`, `~/.claude/skills`, and `~/.codex/skills`.
`agents_visible=0` keeps them off `~/.agents` because Grok and Cursor already
get pstack natively. Vendored files stay verbatim; the etabli workflow
contract remains the canonical router.

## Rejected alternatives

1. **Drop etabli, adopt pstack wholesale.** Loses obvault memory, herdr,
   scopes, multi-runtime symlink deployment, the fail-closed PLAN.md gate, and
   the git/PR contracts. pstack replaces ~30-40% of etabli and is
   Cursor-first while Pi is primary.
2. **Depend on the `pi-pstack` npm port.** Unvetted 0-star community port;
   bypasses the vendor/catalog governance surface this repo already runs.
3. **Import poteto-mode and its playbooks now.** A sticky explicit router
   competes with ambient contract activation (`workflow/spec.md`); deferred to
   a wave-2 decision if task-skill adoption proves insufficient.

## Consequences

- Pi, Claude Code, and Codex gain eight task skills; the etabli routes
  (`/review`, `/plan-loop`, …) stay canonical and unchanged.
- Cursor-specific prose inside the vendored skills (model roles, subagent
  fan-out) degrades to single-model instructions on Pi; documented in
  `docs/pstack-strategy.md`, never patched in place.
- Upstream layout drift fails loudly at sync time (`sync-vendor-skills`
  exits nonzero on a missing skill dir); `UPSTREAM_SHA` pins each synced
  snapshot.
- Wave 2 (21 principles, playbooks, poteto-mode, arena/swarm) remains a
  manifest + catalog-flag flip, to be gated by a follow-up ADR if catalog
  noise or routing ambiguity shows up.
