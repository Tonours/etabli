# Etabli

Agent harness: shared workflow contracts, adapted for Pi and Claude.

## Language

**Route**:
A row of the routing table in `workflow/spec.md`: one trigger, one artifact and one stop condition.
_Avoid_: workflow, mode

**Explicit command**:
A skill or command invoked by name, never chosen from the routing table.
_Avoid_: opt-in, secondary route

**Scope**:
The deployment partition (shared, work, personal) that decides which surfaces receive a skill.
_Avoid_: profile, environment

**Shelf**:
Skills tracked in git but never deployed (`extras/`); promote one by moving it.
_Avoid_: opt-in, vendor, archive

**Surface**:
A location where a runtime loads skills (`~/.pi/agent/skills`, `~/.claude/skills`).
_Avoid_: target, destination

**Scaffold**:
Workflow files copied into a project by `scripts/deploy-workflow` (spec, templates, plan scripts).
_Avoid_: template, bootstrap

**Retired surface**:
A surface etabli no longer manages (ADR-0031); its stale links are left in place, never cleaned up.
_Avoid_: legacy surface, old surface

**T/D counter**:
The review budget of one run (`workflow/skills/review-rounds.md`): T1 and T2 are full rounds, D1 and D2 are delta rounds on the fix diff; findings after D2 block the run.
_Avoid_: review loop, retry

**Deciding code**:
The code that decides a runtime behavior the diff touches, opened by the Logic hunter and recorded as one `file:line` row (`workflow/review-rubric.md`).
_Avoid_: relevant code, context

**Double-sample**:
Two independent same-family adversary passes with recorded run ids: the standard-tier fallback when every eligible cross-model route is technically unavailable, recorded as `cross_model: unavailable (<category>)` (`workflow/skills/adversary.md`).
_Avoid_: second opinion, cross-check

**Daily Pi**:
The Pi review path where the Logic hunter is the only child and the parent runs the Spec pass itself (`workflow/skills/review.md`).
_Avoid_: light review, quick review

**Evidence pack**:
The structured record of plan, decisions and run evidence given to Spec, adversary and lead reviewers, shaped by `workflow/evidence-pack.schema.json`.
_Avoid_: bundle

**PR council**:
The three-pass review of one GitHub PR run by the explicit command `/pr-council-review`; the multi-model routing council is gone (ADR-0013).
_Avoid_: council (alone), review council
