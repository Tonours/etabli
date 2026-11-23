# Implemented: standard tier runs one cross-family review

## Metadata
- Archived: 2026-11-23
- Source plan: `PLAN.md` — standard tier runs one cross-family review; the full review machine stays on high-risk; escaped defects are counted per tier until a dated review
- Source plan SHA-256: `608ab6ff02a8a90b2e65a7afb7a7e921267477ff33e4520f695ada658a831376`
- Status: IMPLEMENTED
- Tier: high-risk; review: full
- Commit / branch: `feat/standard-single-review`, base `d90b4bfa`, head `11907926`
- Workflow initiative: standard-single-review

## Outcome
- A standard run keeps its plan and READY gate, skips the plan adversary, and
  replaces steps 13 and 13b with one fresh review
  (`workflow/skills/review.md` § Standard review). That review is a Logic
  hunter on a non-author family, the Spec pass in the parent (`spec: parent`)
  and the Threat hunter on the same route when its trigger fires. It has no
  code-diff adversary.
- Route: the inversion route, else the next non-author pool route
  (`runner: pool-route`), never the parent's family while a route is untried.
  The deadline is 1800 s. If every route is unavailable, one Logic pass runs
  labeled `same-family` with `cross_model: unavailable (<category>)`. The
  double-sample is deleted.
- Budget: standard gets T1, then one D1 over the whole cumulative patch
  (`workflow/skills/review-rounds.md` § Bounded fix and standard). The run
  upgrades to high-risk when it still blocks, when a fix touches a high-risk
  surface, or when a review is due with both rounds spent. Spent rounds stay
  spent across upgrades.
- High-risk, bounded fix and small are unchanged.
- Every archive carries `- Tier: …; review: …`
  (`workflow/templates/plan-archive.md`, the scaffold `docs/plan/README.md`).
- ADR-0052 sets the review date (2026-12-21), the counting command, the
  cohort, the manual attribution and the restore criterion.

## Context
- Baseline on 2026-11-23: 19 escaped-defect records across the two vaults.
  - 6 personal records, all high-risk.
  - 13 work records, all with an unknown or missing tier.
  - None at standard or bounded-fix, and no archive carried a tier.
- Replay (three reachable records plus one control, inversion route
  `zai/glm-5.3`): 0/3 hit, and the control was clean. All three had also
  escaped the full machine, so the replay does not separate one review from
  four passes.

## Decisions
### One cross-family review at standard, measured
- Context: four passes plus a round machine on the default tier, with no
  measured value.
- Choice: the bounded-fix shape at standard, a dated count, and the restore
  criterion of ADR-0052.
- Rejected options:
  - keep only the adversary;
  - cut high-risk too;
  - measure first;
  - keep the double-sample;
  - a counting script.
- Rationale: no standard record exists to compare against, and the bounded
  fix has used this shape since 2026-11-06.
- Consequences: two or more cohort records attributed to the same removed pass
  restore it. Fewer than five cohort archives extend the window by four weeks.

## Accepted Drift
- Original plan/spec: the review budget at the base contract (T1, T2, D1, D2).
  D2 findings mean `blocked`.
- Implemented reality: after D2 blocked, the owner granted two extra rounds:
  - D3: adversary BLOCK on the GLOSSARY pins. The Logic hunter was
    unavailable (zai 400).
  - D4: Logic GO; adversary BLOCK, 1 medium (other changed lines pinned by
    fragment only). It was folded in `11907926` by pinning every added line
    of every changed file (except tests, the lockfile and the ADR) whole, and
    every removed line negative.
  - The owner then chose to ship with `11907926` unreviewed.
- Why accepted: each adversary round found one more instance of the same
  class (pins too shallow). `11907926` closes the class mechanically, and its
  109 mutations all turn the smoke red.

## Validation Evidence
- command: `bash tests/workflow-scaffold-smoke.sh && bash tests/workflow-contract-coverage-smoke.sh`
  - result: ok at `11907926`.
- command: smoke mutations (one per pin pair or generated pin)
  - result: 179, all red, 0 surviving.
- command: `scripts/verify-agentic-infra full`
  - result:
    - 56/56 at `8936066b`.
    - 55/56 at `11907926`. `pi-tests` timed out resolving the Pi runtime; no
      `pi/` file changed.
    - `scripts/verify-agentic-infra pi` rerun alone: 5/5.
- command: `bun test pi/extensions/__tests__/`
  - result: 135 pass, 0 fail.
- command: entry chain and contract budget
  - result: 326/330; 247 + 141 + 78 = 466/466.
- command: `git grep -n -i "double-sample" -- . ':!docs/plan' ':!docs/research' ':!docs/adr' ':!tests'`
  - result: no output.
- command: `scripts/validate-adrs`; `bash tests/skills-lock-coverage-smoke.sh`
  - result: 52 records ok; lock ok.
- mutation probe: `mutation: unavailable (No write sandbox: linux has no sandbox-exec)`.

## Follow-up State
- Remaining risks:
  - `11907926` (generated pins) had no review round.
  - The single Logic hunter missed all three replay cases.
  - Spec in the parent shares the implementer's context.
  - A Pi child's effective model is not recorded (requested id only).
- Parking lot: none.
- Superseded docs/specs: the double-sample fallback, and the standard
  plan/code-diff adversary.
- Next links:
  - ADR-0052 review on 2026-12-21.
  - Redeploy the scaffolded project copies after merge.
