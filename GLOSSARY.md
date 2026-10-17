# Etabli

Agent harness: shared workflow contracts, adapted for Pi and Claude.

## Language

**Route**:
A row of the routing table in `workflow/spec.md`: one trigger, one artifact and one stop condition.
_Avoid_: workflow, mode

**Core**:
The routes and contracts the READY gate depends on.
_Avoid_: core skills, essentials

**Explicit command**:
A skill or command invoked by name, never chosen by the router.
_Avoid_: opt-in, secondary route

**Scope**:
The deployment partition (shared, work, personal) that decides which surfaces receive a skill.
_Avoid_: profile, environment

**Shelf**:
Skills tracked in git but never deployed (`extras/`); promote one by moving it.
_Avoid_: opt-in, vendor, archive

**Surface**:
A location where a runtime loads skills or commands (`~/.pi`, `~/.claude`).
_Avoid_: target, destination

**Scaffold**:
Workflow files copied into a project by `scripts/deploy-workflow` (spec, templates, plan scripts).
_Avoid_: template, bootstrap

**Retired surface**:
A surface etabli no longer manages (ADR-0031); its stale links are left in place, never cleaned up.
_Avoid_: legacy surface, old surface
