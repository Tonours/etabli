# PLAN.md

Full template for broad, risky, UI-heavy, multi-surface or long-running work.
Keep it a restartable working contract, not a research essay. Delete sections
marked optional when they do not apply.

## Meta
- Subject:
- Type: bugfix | feature | refactor | migration | investigation
- Status: DRAFT | CHALLENGED | READY
- Branch:
- Source:
- Last revised:
- Archive: pending until implemented and validated

## Goal
What changes and why it matters, in 1-3 sentences.

## Workflow Contract
- Route:
- Role:
- Tier: small | standard | high-risk
- Budget (iterations/time/tools; token totals are telemetry, never a stop condition):
- Stop condition:
- Required evidence:

## Acceptance Criteria
One line each: `AC-n [product|process|judgment]: criterion`; a product AC adds `Proof: action, result[, side effect]`.
- [ ] AC-1:

## Problem
- Current behavior:
- Expected behavior:
- User impact:

## Repos
- Owner: this repo
- Satellite: none / `<repo-name>` — <what changes there>

## Scope
### In
-

(Risky? Name files/areas; required for READY.)

### Out
-

## Facts And Assumptions
### Observed Facts
- file/path/command/source:

### Assumptions
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
- Input domain / bounds:
- Regression family; failing, valid and invalid neighbors:
- Why this approach over the alternatives:

## Product Dogfood (optional: user-facing, UI or browser work)
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

## Execution Slices
### Slice 1
- Goal:
- Files / areas:
- Checks:
- Rollback point:

## Checks
- command:
  - expected:
  - last run:
- Manual or UI check:
  - expected:
  - last run:

## Risks
- Risk:
  - Impact:
  - Mitigation:

## Decision Log
- YYYY-MM-DD:

## Review Changes
- Plan adversary (model, `shasum -a 256 PLAN.md` at dispatch, verdict, deltas):
- Code review and code-diff adversary (reviewers, rounds, verdicts):
- simplify: / quality:

## Open Questions
- None / ...

## Ready Gate
- READY only when `workflow/spec.md` § Minimal READY gate holds.

## Notes / Handoff
- Branch, sha, done, pending, next action, do-not-redo:
