# Implemented: Sandboxed mutation probe for implementation-loop step 12

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — sandboxed mutation probe for implementation-loop step 12
- Source plan SHA-256: `0519c997e61d37192ff398b12fac36ab91b0eb19159f0c7cd21512caa366d67e`
- Status: IMPLEMENTED
- Commit / branch: `feat/mutation-probe`, based on `1ba7204c`
- Workflow initiative: review-robustness (phase 2, item 1)

## Outcome
- Tool (AC-1): `workflow/runtime/mutation-probe.mjs` mutates the added lines
  of a diff against `--base` (operator swaps and deletion of
  `return`/`throw`/`exit` lines; comments, quoted text, heredoc bodies and
  multi-line strings masked), runs the focused test once per mutant in a
  fresh APFS clone and prints a table plus `survived: N of M scored`.
  Every command it starts runs under `sandbox-exec` with a per-step profile:
  writes outside temp dirs, `--allow-write` and the step's own clone are
  denied and stop the writer. A stopped process in the step's tree (group
  plus descendants by parent pid) makes the outcome `denied`, unscored.
  macOS only; without a sandbox it exits 2 with `no write sandbox`.
- Contract (AC-2): step 12 runs the probe on standard and high-risk diffs
  that touch executable sources; each survivor gets a killing test or a
  one-line justification; records `mutation: N survived of M, K justified`,
  `n/a`, `inconclusive`, `unavailable`. Surfaces: implementation-loop step
  12 and Completion Evidence, both plan templates, the `implement` and
  `plan-implement` skills, `workflow/answer-quality.md`; scaffold smoke
  asserts each line.
- Check (AC-3): row `full shell-docs mutation-probe-test` in
  `workflow/runtime/agentic-infra-checks.tsv`; off macOS only the `unit:`
  cases and the refusal case run.
- Decision (AC-4): ADR-0040, review date 2027-01-29, adoption rule: a later
  implemented-plan archive with a positive `mutation:` line, or the tool,
  its test, its row and the contract text are deleted.

## Context
- Test gaps are the largest true-positive class in the private review
  corpus, and test strength was only read, never executed.
- M1 (throwaway prototype, five shipped commits): 18 mutants, 15 killed,
  3 survived; one survivor was a real gap, closed by `1ba7204c`.

## Decisions
### One kernel rule set instead of per-vector escape checks
- Context: the first plan defended the original tree with one check per
  escape vector; seven adversary rounds each found another vector.
- Choice: `sandbox-exec` per step, canonical paths, literal deny on every
  ancestor of the protected roots, SIGSTOP on denial, process-tree polling.
- Rejected options: keep folding per-vector checks.
- Consequences: macOS only; a test that writes outside temp dirs needs
  `--allow-write`, named by the baseline failure.

## Accepted Drift
- Built-in checks, git reads, the copy and the bootstrap run as argv, not
  `bash -c`; the first `rev-parse` runs under an inline profile.
- Denial detection tracks the process tree, not only the group (a `setpgrp`
  timeout wrapper escaped the group and hung a baseline).
- `/private/var/tmp` is allowed (bash 3.2 writes here-documents there);
  `gc.auto=0` and `maintenance.auto=false` on every git call (a detached
  auto gc rewrote the pristine copy); `--timeout` capped at 86400; `/bin/ps`
  and `/bin/cp` by absolute path; non-UTF-8 targets skipped and printed.
- Diff reads add `--text`, `--inter-hunk-context=0` and
  `diff.suppressBlankEmpty=false`; several `--paths` values are a union.
- Why accepted: each was measured or found by review, and recorded in the
  plan's Decision Log.

## Validation Evidence
- command: `node --test tests/mutation-probe.test.mjs`
  - result: 35 tests, 34 pass, 1 skipped (Linux refusal case).
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 13/13 and 43/43.
- command: `bun test pi/extensions/__tests__/`
  - result: 62 pass, 0 fail.
- command: `bash tests/workflow-scaffold-smoke.sh`
  - result: ok.
- End-to-end rerun of the five M1 targets with the final tool: per-mutant
  outcomes identical to M1, every original unchanged.
- Dogfood on its own `unit:` cases: `generated 223`, 89 survived of 220
  scored. Four survivors in pure functions got killing tests (each mutant
  rerun and killed). The other 85 are process, file and git I/O reached
  only by the integration suite, which cannot run under the probe because
  macOS refuses a nested sandbox.
  - `mutation: 89 survived of 220, 85 justified`
- Privacy grep against a private term list over every commit's tree,
  message, people fields and added lines: 0.

## Review
- Plan: four cross-model rounds on the sandbox design; READY by owner
  decision after round 4.
- T1: Logic and Spec GO WITH NOTES; cross-model adversary BLOCK (5 high,
  1 medium); end-to-end found a `setpgrp` escape and a detached auto gc.
  Folded; the new-hard-link finding was refuted by measurement.
- T2: Logic and Spec GO WITH NOTES (1 medium); adversary BLOCK on comment
  and quote masking and `-diff` attributes. Folded; new hard links now
  pinned by two tests.
- D1: both GO WITH NOTES; adversary BLOCK on shell escapes and heredoc
  words. Folded; pid reuse inside one 100 ms poll refuted (pids are
  sequential up to 99999).
- D2: both GO WITH NOTES; adversary BLOCK on rare shell-mask forms. D
  exhausted; the owner chose to ship with a tested post-D2 fold and the
  remaining forms stated as ADR residuals.

## Follow-up State
- Remaining risks: a test that reaps its own stopped child between two
  polls turns a denial into `killed`; detached daemons are outside the
  supported domain; rare shell forms (a literal backslash or quote inside a
  quoted heredoc delimiter, a delimiter split by a line continuation, an
  escaped space before `#`) can mask too many or too few lines;
  `sandbox-exec` is deprecated.
- Parking lot: phase-2 items context pack (M2), patch chunking with a
  private bench, proof tests.
- Superseded docs/specs: none.
- Next links: ADR-0040 review on 2027-01-29.
