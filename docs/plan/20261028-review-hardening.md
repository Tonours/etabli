# Implemented: Review hardening from external review feedback

## Metadata
- Archived: 2026-10-28
- Source plan: `PLAN.md` — Review hardening from one month of external review feedback
- Source plan SHA-256: `452eccaf02a253eb63f87883632ae7e47ff1df857eff42cef6679591e3c6e9fc`
- Status: IMPLEMENTED
- Commit / branch: `feat/review-hardening`, based on `daf6779b`
- Workflow initiative: review-hardening

## Outcome
- Template delivery (AC-0): every runner puts the hunter template's full text
  in the brief, and the lead records `template: inline|missing`. The Finding
  Format gate blocks `GO` and `GO WITH NOTES` on `template: missing` and on a
  hunter report whose last line is not `STATUS: complete`. The Logic, Threat
  and Spec templates end on a `STATUS` line, so truncation stays visible.
- Plan stage (AC-5): plan-loop step 6 records four inventories (sibling
  surfaces, deploy state, lifecycle states, and per-behavior test mutations),
  and the plan adversary checklist asks for them.
- Privacy (AC-7): work-org vault routing, the machine-local plugin id and the
  fix-verification skill name are read from machine-local config. A missing
  verify skill leaves the head due (`verify: unconfigured`, no watermark).
  `pr-review-watch` reads it from a sha-bound marker that `run_verify` writes,
  not from the exit code alone.

## Not shipped
- AC-1 to AC-4 (execution tables, as an isolated hunter or inside Logic;
  tightened Logic lenses; wider Threat trigger; Spec scope map and Standards
  conventions) are reverted. The pre-registered eval was INCONCLUSIVE. Both
  candidates stay on local, unpushed branches.

## Evaluation (cases named by letter; the case map stays private)
- Corpus: one month of review comments (bots, humans and a validator bot) on
  four work repositories, classified by defect class and by the lens that
  should own it.
- Arms: A = main, B = isolated Execution hunter, C = execution tables inside
  Logic. Full chains (Logic, Spec, Standards, Threat when triggered, lead),
  isolated runners with read audits; void runs rerun once.
- Targeted set, six owner escapes, descriptive only. Hits before tuning: A 1,
  B 3, C 2. After one tuning pass: B 2, C 2. Noise: A 15, B 22, C 16.
- Held-out set, eight cases (six findings and two controls), picked by a fresh
  selector after the candidates were frozen:

  | Arm | Complete | Hits | Noise | Median tokens | Median wall |
  |---|---|---|---|---|---|
  | A | 8/8 | 2 | 22 | 469k | 69 s |
  | B | 7/8 | 3 | 33 | 861k | 104 s |
  | C | 7/8 | 3 | 25 | 675k | 112 s |

- Neither candidate reaches +2 hits. C also misses a case A hits, so it fails
  the floor: INCONCLUSIVE, with no gain claimed.
- Signal kept for a later attempt: the execution tables caught two held-out
  defects that A missed, and hunters cut their own work short on patches of
  5,000 to 10,000 lines.
- Lead probes on the shipped lead: clean case GO. Each of these BLOCKs on the
  intended gate: deciding code not run, `template: missing`, a truncated
  hunter.

## Review
- Plan: ten cross-model adversary rounds; READY at round 10.
- T1: Logic GO. Spec findings were refuted (the Pi runner already inlines the
  template). The cross-model adversary returned 3 mediums, all fixed.
- T2: Logic GO WITH NOTES. Spec lows got a Spec STATUS assertion. The
  cross-model adversary found an rc 5 collision, which was fixed.
- D1: Logic GO WITH NOTES. The cross-model adversary returned 2 mediums: a
  configured retry at the cap could not resume, and a child's rc 5 read as
  unconfigured. Both were fixed with the sha-bound marker and are
  mutation-tested.
- D2: Logic GO; cross-model GO WITH NOTES, no findings.

## Checks
- `scripts/verify-agentic-infra core` 13/13 at each commit, plus the flow
  smoke with a mutation check on the marker guard.
- A privacy grep against a private term list over every commit's tree,
  message and added lines.
- Ship (push, local and remote deploys) is recorded outside this archive.
