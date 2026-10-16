---
status: accepted
date: 2026-10-16
supersedes: [ADR-0020, ADR-0021, ADR-0023]
tags: [skills, vendor, pstack, pi, claude]
affected_components: [pi/agent/settings.json, vendor/sources.tsv, workflow/runtime/skill-surface.tsv, extras/skills, pi/skills, claude/scopes, scripts/update-vendor-skills, scripts/lib/managed-surfaces.sh]
---

# Prune the skill surface and drop pstack

The managed skill surface shrinks to what the workflow uses. pstack (`npm:@zenspc/pi-pstack`) leaves Pi entirely. The ember-skills and adonisjs-skills vendors go, mattpocock keeps 7 skills (codebase-design, domain-modeling, grill-with-docs, improve-codebase-architecture, prototype, research, wizard), and extras keeps grill-me, react-doctor-100 and coolify. The ship, ci-fix, github-pr-review, pr-review, pr-qa and sec-pr routes and the three playwright skills are removed; pr-council-review covers PR review. thermo-nuclear-code-quality-review becomes model-invocable. `scripts/update-vendor-skills` refreshes every vendor in one step. This supersedes ADR-0020, ADR-0021 and ADR-0023.

## Considered Options

- **Prune to the used set (chosen).** Each skill description costs resident context in both runtimes, and the Pi block sat above its budget with pstack loaded; most removed skills had no recent use.
- **Keep everything and hide it behind disable-model-invocation.** Cheaper to undo, but it kept the sync, lock, deny-list and test machinery alive for skills nobody invokes.

## Consequences

- Removed skills stay recoverable from git history; vendor/README.md lists the restore steps for a dropped pack.
- Stale links into a nested vendor tree (vendor/mattpocock/skills/engineering/<name>) are now pruned on deploy; the managed-root match used to miss them.
- Pi loses poteto-mode and the other pstack skills; the workflow contract stays canonical for planning, review and verification.
