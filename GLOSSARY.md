# Etabli

Agent harness: shared workflow contracts, adapted for Pi, Claude and Codex.

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
The review budget of one run (`workflow/skills/review-rounds.md`): T1 and T2 are full rounds, D1 and D2 are delta rounds on the fix diff; findings after D2 block the run. A bounded fix and a standard run get T1 and D1 only (a standard D1 covers the whole cumulative patch); one counter spans tier upgrades.
_Avoid_: review loop, retry

**Deciding code**:
The code that decides a runtime behavior the diff touches, opened by the Logic hunter and recorded as one `file:line` row (`workflow/review-rubric.md`).
_Avoid_: relevant code, context

**Standard review**:
The single fresh-context review of a standard run: one Logic hunter on another model family, Spec in the parent; a labeled `same-family` pass only when every eligible route is technically unavailable, recorded as `cross_model: unavailable (<category>)` (`workflow/skills/review.md`).
_Avoid_: light review, second opinion

**Daily Pi**:
The Pi review path where the Logic hunter is the only child and the parent runs the Spec pass itself (`workflow/skills/review.md`).
_Avoid_: light review, quick review

**Entry chain**:
The files an agent reads before routing (`AGENTS.md`, `workflow/spec.md`, `workflow/agent-rules.md`), capped by ADR-0042; `workflow/skills/` loads per route and stays outside it.
_Avoid_: hot context, hot chain

**PR council**:
The three-pass review of one GitHub PR run by the explicit command `/pr-council-review`; the multi-model routing council is gone (ADR-0013).
_Avoid_: council (alone), review council
