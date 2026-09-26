---
status: accepted
date: 2026-09-25
tags: [workflow, routing, skills, minimal-core]
affected_components: [workflow/runtime/workflow-router-core.mjs, workflow/spec.md, workflow/runtime/skill-surface.tsv, claude/scopes, extras/skills]
---

# Recenter the router on the PIV core

Etabli's deterministic router now classifies prompts into eight core routes only (answer, ops-stop, plan-loop, implement, plan-implement, review, verify, adversary); work commands (/linear-*, /bug-check, /pr-review, /pr-qa, /sec-pr, /ci-fix, /spec-guide) become explicit commands in the Claude work scope, never routed, and non-core Pi skills move to an undeployed extras/ shelf. This narrows ADR-0007 without superseding it: the guards stay authoritative, only the routed set shrinks. The motive is maintained surface (17 routes and 49 skill entries each carried fixtures, corpora and eval pins), not a token saving, so no ADR-0019 measurement is claimed.

## Consequences

- Slash prompts already bypass the classifier, so explicit `/ci-fix` keeps pushing under its own contract; natural-language pushes of a PR/branch/commit and Linear ticket creation now route to ops-stop.
- Natural-language Linear ticket work routes to plan-implement (implement with a READY plan) instead of a dedicated route.
- The Jev route-capsule runtime was removed: its promotion was SHA-bound to the router source, so any router change failed it closed. The disabled Jev semantic shadow keeps its original route list until its removal.
- The runtime skill canary tool was removed with its target skill, which could not stay deployed on the shelf.
