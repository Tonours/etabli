# Implemented: risk-triggered Threat axis for the pre-push self-review

## Metadata
- Archived: 2026-10-28
- Source plan: `PLAN.md` — Threat axis for the pre-push self-review
- Source plan SHA-256: `2954d0a4153c3f0d5bf3ef324913758e42258b6976e81cbde90943d077d33a8d`
- Status: IMPLEMENTED
- Commit / branch: `feat/threat-review-axis`, based on `90c8ea31`
- Workflow initiative: threat-review-axis

## Outcome
- New `workflow/templates/review-threat-hunter.md` (`Axis: Threat`), deployed by `scripts/deploy-workflow` and asserted by the scaffold smoke. It has six mandatory tables:
  - deciding inputs;
  - entry-point inventory built from the asset's accessors, reads included;
  - reused guards;
  - deferrals;
  - rollout;
  - attack tests.
- `workflow/skills/review.md` step 5b:
  - the trigger fires on an access decision, a trust boundary, or the accepted inputs or responses of a public API;
  - the hunter is dispatched on the Logic runner;
  - the status line is `threat: isolated|n/a`;
  - the parent executes attack tests inside an implementation loop, with outcomes `proven`, `refuted` (real decision code, unmocked, plus a control request) or `unproven`.
- Rubric:
  - § 4b covers Threat;
  - deferrals refute nothing when the goal depends on them, and a follow-up only sets the disposition;
  - an out-of-diff citation exception exists for Threat;
  - GO requires a complete Threat report.
- Lead: Threat dispositions, a sixth status line, and a block on `partial:` tables.
- Reviewer agent: accepts `Axis: Threat`, `maxTurns` 24 → 40.
- Adversary agent and code-diff contract: hunt client-controlled deciding inputs and ungated entry points.
- Escaped-defect bucket `deferral_accepted`.

## Context
- Two employer pull requests, cases A and B, passed three automated review passes, yet six findings arrived afterwards. All six sat around the diff, none on its lines: an unbound header pair, ungated inbox reads, guard over-refusal swallowed by a `catch`, the leftmost-XFF allowlist waived as a pre-existing ticket, a rollout with no log-only phase, and OpenAPI missing 401/403.
- The live PR bodies were edited after the fixes. The eval used the historical bodies, from GraphQL `userContentEdits`, with the Review sections stripped.

## Decisions
### Separate Threat axis, not folded into Logic
- Context: threat replay needs the Intent; Logic is intent-blind by design.
- Choice: a fourth hunter, triggered by risk.
- Rejected options: folding into Logic (codex plan pass 1).
- Rationale: keeps Logic independent and its 8 lenses unchanged.
- Consequences: one more fresh run on access, trust-boundary and public-API diffs only.
### Attack tests are specs; the parent executes them
- Context: the `reviewer` is read-only, and executed proof is the strongest precision lever (SWT-Bench).
- Choice: the hunter writes the spec rows. The parent runs them inside an implementation loop. A pure review keeps every finding `unproven`.
- Consequences: green attack tests ship as regression tests and are reviewed under the normal budget.
### Reuse existing escaped-defect buckets, add only `deferral_accepted`
- Rationale: `lens_missing` and `retrieval_gap` already cover the other shapes.

## Accepted Drift
- Original plan/spec: the eval runs each case once on the final template.
- Implemented reality:
  - AC-7 ran on `7c6c1a44` (tuned) and was rerun on the final `c9b91c39`. The D1 fix changed only the parent-side attack-test sentence.
  - AC-7b and AC-7c ran on `7c6c1a44`.
  - `reviewer` maxTurns 40 is not live in the eval: the installed agent symlinks to `main` at 24, and every tuned run finished within it.
- Why accepted: the hunting instructions are identical between the two hashes.

## Validation Evidence
- Eval, frozen and hashed inputs in `/tmp/threat-eval/`, scratch:
  - Baseline: Logic and Spec on both cases missed every target.
  - First template `b3041dde`:
    - case A found XFF but rated it medium, as accepted risk;
    - case B hit the turn cap and missed the pairing and the inbox reads.
  - After one tuning pass (`7c6c1a44`) and on the final `c9b91c39`:
    - case A: high XFF, `blocks goal`, BLOCK;
    - case B: high pairing of two client-supplied scope headers, inbox reads ungated, BLOCK.
- AC-7c full chain on case A: trigger, Logic + Spec + Threat, lead `threat: isolated`. The attack test ran with `tsx --test` against the real allowlist middleware: `x-forwarded-for: 203.0.113.10, 198.51.100.7` resolves instead of `ForbiddenError`, so **proven**, while the control passes. Verdict: BLOCK. Docs-only `90c8ea31` gives `threat: n/a`.
- AC-7b, held-out case C: **miss**. The hunter asserted that an error yields an empty set, but the hook reads `data`, which React Query keeps after a failed refetch.
- Leakage: 0 reads under the worktree, brain or obvault across 15 eval transcripts.
- Review:
  - T1:
    - Logic GO;
    - Spec 4 low (3 accepted, 1 dismissed: size 3,944 bytes, under 4,300);
    - codex `gpt-6.1-sol` code-diff BLOCK, 2 medium, accepted: partial tables passed the gate; `refuted` was possible with the protection mocked.
  - D1: codex GO with both resolved; Logic 1 low (template `refuted` drift), fixed.
  - D2: Logic GO, clean.
- command: `bash tests/claude-agents-smoke.sh`
  - result: ok
- command: `bash tests/workflow-scaffold-smoke.sh`
  - result: ok
- command: `scripts/verify-agentic-infra core`
  - result: 14 PASS, `pi-tests` FAIL on 2 tests ("unable to resolve active Pi runtime"), identical on `main` (environmental).

## Follow-up State
- Remaining risks:
  - The held-out miss shows no lens for stale state on failure in client caches (React Query, SWR, Apollo).
  - Rollout breakage lands in the table, not as the medium finding the template asks for, on both case A runs.
  - Two cases are targeted regressions, not a generalization claim.
- Parking lot:
  - A "cache keeps data on error" row for Threat or Logic degraded modes, to measure on the next escape.
  - Measure Threat hunter cost: 15–31 tool uses per run.
- Superseded docs/specs: none
- Next links: brain `ref/review-effectiveness-log.md` (six escaped-defect entries, uncommitted, next to the pending privacy-migration hunk).
