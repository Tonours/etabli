---
status: accepted
date: 2026-08-28
tags: [tooling, skills, vendor, pstack]
affected_components: [vendor/sources.tsv, workflow/runtime/skill-surface.tsv, scripts/lib/skill-catalog.sh, docs/pstack-strategy.md]
---

# Adopt pstack poteto-mode and principles as wave 2, opt-in

## Context

ADR-0020 deferred poteto-mode and the 21 principles to a wave-2 decision
gated on wave-1 coverage proving insufficient. The user reviewed the wave-1
landing and directed wave-2 adoption explicitly (poteto-mode, playbooks,
principles), accepting the catalog growth ahead of that gate. Two facts
shaped the mechanism: poteto-mode declares `name: Poteto Mode` (display case,
not a valid skill slug), which would break vendor-loop linking on Pi, Claude
Code, and Codex; and the install vendor loop links by declared name, so the
shared catalog helper needed a slug-validation fallback.

## Decision

Vendor `poteto-mode` (its 22 playbooks ship inside the skill folder) and the
21 `principle-*` skills from the same `pstack` monorepo snapshot
(`397c8660da6d`). Deploy via catalog rows (`source=pstack`, `0 0 1`) to
`~/.pi/agent/skills`, `~/.claude/skills`, `~/.codex/skills` — 30 pstack
skills total. `scripts/lib/skill-catalog.sh` now falls back to the directory
basename when a declared `name:` is not a valid slug (`^[a-z0-9][a-z0-9-]*$`),
covered by `tests/skill-catalog-name-smoke.sh`.

On etabli, poteto-mode is **opt-in**: the ambient workflow contract
(`workflow/spec.md`) remains the canonical router for ordinary prompts;
`/poteto-mode` is an explicit user-selected mode, matching its upstream
`disable-model-invocation: true` intent. This supersedes ADR-0020's rejection
of importing poteto-mode "now" — the import happens with the opt-in
mitigation instead of waiting for a coverage failure.

## Rejected alternatives

1. **Wait for the ADR-0020 coverage gate.** User directive overrides; the
   adoption is reversible by catalog-flag flip if routing ambiguity appears.
2. **Catalog-less manual link for poteto-mode.** Survives installs (prune
   only removes dead targets) but is invisible to the skills lock and canary
   surfaces and is not reproducible on a new machine.
3. **Thin adapter skill wrapping the vendored poteto-mode.** Relative path
   resolution through per-surface symlinks is fragile cross-machine.
4. **Vendoring the remaining 14 pstack skills to close dangling references.**
   Scope creep beyond the user's ask; the references degrade gracefully.

## Consequences

- The Pi/Claude/Codex skill catalogs grow by 22 (Pi list ~76 entries);
  reversible per-row.
- poteto-mode references skills and mechanics that are not vendored
  (arena, swarm, recall, unslop, no-comments, technical-writing,
  figure-it-out, reflect, automate-me, make-bot-ui, teach,
  typescript-best-practices, show-me-your-work, bro; Cursor built-ins
  create-skill, /loop, AskQuestion, Task model roles; cursor-team-kit
  deslop/control-cli/control-ui; the poteto-agent subagent definition at
  `pstack/agents/`, outside the skills-only sync). On etabli surfaces these
  degrade to their nearest local behavior; the full inventory lives in
  `docs/pstack-strategy.md`.
- poteto-mode's `reminder:` frontmatter is an always-on nudge on Cursor and
  an unknown field elsewhere — a residual self-trigger vector documented in
  the strategy doc, acceptable while the mode is wanted.
- The name-slug fallback in `skill-catalog.sh` is a shared-installer-surface
  change; it was reviewed at the high-risk tier with a cross-model adversary
  pass (`zai/glm-5.3`) per `workflow/skills/adversary.md`.
