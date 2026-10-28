# Implemented: Threat axis follow-ups

## Metadata
- Archived: 2026-10-28
- Source plan: `PLAN.md` — Threat axis follow-ups, privacy scrub and ship
- Source plan SHA-256: `931778f9543e6b677cd3012404c2520c5c8a61324cc6c0fb2fa0b7d019f0dc3c`
- Status: IMPLEMENTED
- Commit / branch: `feat/threat-review-axis`, based on `90c8ea31`
- Workflow initiative: threat-review-axis

## Outcome
- Stale client cache: the Threat evidence bar and the Logic `degraded modes`
  lens check a decision read from a client cache (React Query, SWR, Apollo…)
  on the entry after a failed refetch. An error flag or an empty default on the
  hook result refutes nothing.
- Rollout: a legitimate caller broken on deploy with no flag, log-only phase or
  measurement is a `medium` finding, even when the Intent discloses the break.
  A caller in the class the change exists to refuse is not legitimate. Every
  table row the rules turn into a finding appears under Findings.
- The Pi loader test resolves an asdf `pi` shim.

## Not shipped
- The pr-council-review phase-A-only mode (AC-7b) is `blocked`. Every review
  round after T1 found blocking defects on that surface, and the D budget is
  exhausted. Its commit stays on a local, unpushed branch. The last fixes are
  mutation-tested but not reviewed. It needs a new review run before it can
  ship.

## Evaluation (cases named by letter; the case map stays private)
- Config hash Hc: sha256 of the template, skill, rubric and agent-file
  manifest. History:
  - `3e850d83` first freeze;
  - `660b089d` after the one tuning pass (rollout refused-class rule);
  - `f7210053` after the Spec T1 fix to the Logic lens.
  Runs that depended on a changed file were rerun. Runs ending on the turn cap
  are void.
- Targeted set on `660b089d` (Threat runs; the later change touched only the
  Logic template):
  - A (IP allowlist on a public API): high on the client-controlled leftmost
    forwarded-IP entry, plus a medium rollout finding. Pass.
  - B (blocked team and environment): high on the unbound pair of
    client-supplied identifiers, and the reads appear ungated. The negative
    control passes: blocked members are marked refused class, no rollout
    finding. Pass.
  - C (client permission cache): the stale-`data` finding is present but rated
    low, reasoned from the code (refetch disabled). Hit, severity below the
    target.
  - Tuning disclosure: before tuning, the first B run raised a rollout finding
    on the refused class. The held-out list had already been selected, and the
    parent had seen its one-line summaries. The tuning touched only the
    rollout rule.
- Full chain on A at `f7210053`:
  - Logic GO, Spec no findings, `threat: isolated`;
  - the attack test against the real decision code is `proven`: a forged
    leftmost entry passes, and the control passes;
  - the lead returns `Verdict: BLOCK`;
  - the docs-only negative control gives `threat: n/a`.
- Held-out set, selected by a fresh agent after Hc, once each, no tuning:
  - H1 (escaped, stale permission cache): hit, high;
  - H2 (escaped, routes missing two guards): void twice on the 24-turn cap;
  - H3 (escaped, write-side related routes use the parent scope): hit, medium;
  - H4 (control): 2 high and 1 medium, audited against the code. One high is
    introduced by the diff (a type error makes the limiter fail open). The
    others are pre-existing behavior the diff relies on, so none is false.
  - Conclusion limited to the sample: 2 of 2 completed escaped cases hit.

## Review
- Plan: four cross-model adversary passes, then READY.
- T1:
  - Spec, 1 low (Logic lens incomplete): fixed;
  - Logic, GO WITH NOTES: a validator COMMENT was ignored; fixed;
  - cross-model, 3 findings (dedup as resolution, loose identity match,
    out-of-diff inline comments): fixed.
- Later rounds, all on the pr-council-review surface:
  - T2 (4 findings), D1 (2) and D2 (2), each fixed. Logic was GO in each
    round, and the cross-model adversary returned BLOCK each time.
  - One item is accepted risk: an approval by the configured login counts as
    the validator's completion.
  - D2 had findings, so the run is `blocked` for that surface.
- The Threat and Logic template changes drew only T1's low finding, and it is
  fixed.
- simplify: removed 1; quality: pass.

## Checks
- `scripts/verify-agentic-infra core`, `bun test pi/extensions/__tests__/`, and
  the flow, gates and signals pr-review smokes run on the frozen head.
- A privacy grep against a private term list over every commit since
  `origin/main` must be empty before the push.
- Ship (push, local and remote deploys, `maxTurns: 40` proof, fleet decision)
  is recorded outside this archive.
