---
status: accepted
date: 2026-08-28
tags: [tooling, skills, vendor, pstack, policy]
affected_components: [scripts/sync-vendor-skills, docs/pstack-strategy.md, docs/vendor-skills.md, tests/sync-vendor-subpath-smoke.sh]
---

# Amend vendored-verbatim with a sync-time path-adaptation table

## Context

ADR-0020 established that vendored skill files stay verbatim: adaptation
lives in docs, never in the trees, so `sync-vendor-skills` can re-copy from
upstream without conflicts. Real usage exposed the cost: pstack's generated
and discovered skill surfaces point at `.cursor/skills/` (create-verification-skill,
maintain-verification-skill, automate-me, reflect's reviewers) — a path no
etabli-deployed runtime discovers, so every generated verification skill
lands where only Cursor reads it.

The user directed the paths be adapted per runtime. One-off edits would be
erased by the next sync; a fork would lose upstream tracking (ADR-0020's
rejection). The remaining honest option is a declared adaptation applied by
the sync tool itself.

## Decision

Vendored content remains verbatim **except** a declared path-adaptation
table applied by `scripts/sync-vendor-skills` after each skill copy:

- `.cursor/skills/` → `.claude/skills/`
- `.cursor/plugins/` → `.claude/plugins/`

`.claude` is the single deterministic target: it is Claude Code's native
project-local and user-level discovery surface, the machine already links
there, and Pi/Codex read project files by path regardless. Runtime-
conditional prose was rejected as non-deterministic under sed and
ambiguous to the model reading the skill.

Intentional remainders (Cursor facts that degrade harmlessly and are not
skill surfaces): `~/.cursor/projects/` transcript globs, `~/.cursor/rules/
pstack-models.mdc` (a real file on this machine, read as plain text by any
runtime), and `.cursor/worktrees/`. Transforming those would falsify their
semantics rather than adapt them.

The smoke test asserts the transform so the layer cannot silently rot.

## Consequences

- Re-syncs remain the single source of upstream movement; adaptations are
  idempotent and survive every sync.
- Generated `verify-<app>` skills now land in `.claude/skills/` — natively
  discovered by Claude Code in-project; Pi and Codex users read them by
  path (documented in `docs/pstack-strategy.md`).
- Upstream rewrites of the affected paragraphs surface in the sync diff
  review like any other drift; a vanished match is a no-op.
- Future adaptation needs extend the table (with an ADR reference), never
  hand-edit vendored files.
