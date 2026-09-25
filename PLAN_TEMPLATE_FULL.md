# PLAN.md Full Template

Use this for broad, risky, UI-heavy, multi-surface, or long-running work.
Keep it as a restartable working contract, not a research essay.

## Meta
- Subject:
- Type: bugfix | feature | refactor | migration | investigation
- Status: DRAFT | CHALLENGED | READY
- Source:
- Last revised:
- Archive: pending until implemented and validated

## Goal
Describe in 1-3 sentences what will change and why it matters.

## Workflow Contract
- Router decision:
- Role:
- Pattern:
- Goal verifier:
- Operational budget (iterations / time / tools; model-token totals are telemetry, never a stop condition):
- Context reset threshold:
- Escalation:
- Planner output:
- Challenger focus:
- Implementer boundaries:
- Verifier checks:
- Reporter artifact:
- Stop conditions:
- Required evidence:

## Acceptance Criteria
- [ ] ...

## Problem
- Current behavior:
- Expected behavior:
- User impact:

## Repos
- Owner: this repo
- Satellite: none / `<repo-name>` — <what changes there>

## Scope
### In scope
-

(Risky change? Name files/areas — the plan adversary blocks READY without them.)

### Out of scope / Non-goals
-

## Facts And Assumptions
### Observed Facts
- file/path/command/source:

### Assumptions To Verify
- None / ...

## Context Map
- Product areas:
- Likely files / modules:
- Existing docs / source of truth:
- Commands discovered:

## Requirement Trace
| Requirement / source | Observed state | Gap / ambiguity | Decision | Step / expected evidence |
| --- | --- | --- | --- | --- |
| | | | | |

## Approach
Describe the selected approach and why it is proportionate.
Mention rejected options only when they changed the decision.

## Product Dogfood
Use this section only for user-facing/UI/browser-impacting work.

### User Flows
- Flow:
  - Entry point:
  - Actions:
  - Branches:
  - Side effects:
  - True end state:

### Scenario Matrix
| Scenario | Flow branch | Preconditions | Steps | Expected result | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |

### Product Lens
- Primary users/personas:
- Paper cuts to check:
- Sharp paper cuts that should enter the fix loop:

### Browser/UI Evidence
- Observable surface:
- Artifacts:
- Evidence pack path / target hash / environment fingerprint:
- Execution provenance: parent_observed_execution | proxy_supported | blocked
- Blocked external legs:

## Large Program Manifest
Use only when the READY plan explicitly authorizes sidecars and independently
ownable units. Otherwise delete this section.

- Manifest path:
- Coordinator / canonical ledger writer:
- Artifact root:
- Positive max in flight:
- Unit DAG and non-overlapping scopes:
- Worktree policy:
- Independent verifier policy:
- Retry / zombie reconciliation:
- Runtime capability: confirmed | proxy_supported | blocked | unknown

## Execution Slices
### Slice 1
- Goal:
- Files / areas:
- Checks:
- Rollback point:

### Slice 2
- Goal:
- Files / areas:
- Checks:
- Rollback point:

## Validation Plan
- Automated checks:
- Manual checks:
- UI/browser checks:
- Regression risks to watch:
- Evidence required for done:

## Progress Log
- YYYY-MM-DD:

## Decision Log
- YYYY-MM-DD:

## Review Changes
- (Adversary passes record deltas here — canonical location.)

## Handoff State
- Current state:
- Last validated state:
- Known failures:
- Next action:

## Risks
- Risk:
  - Impact:
  - Mitigation:

## Open Questions
- None / ...

## Ready Gate
- [ ] Goal and acceptance criteria are concrete
- [ ] Scope and non-goals are bounded
- [ ] Observed facts are separated from assumptions
- [ ] Steps/slices are executable in order
- [ ] Checks are named and proportionate
- [ ] Risks are identified or explicitly none
- [ ] No blocking open questions remain
