# Implemented: Mutation probe refuses where a denied write does not stop the writer

## Metadata
- Archived: 2026-10-29
- Source plan: `PLAN.md` — mutation probe refuses where a denied write does not stop the writer
- Source plan SHA-256: `a1239435b66cabf59f305d6f078a189e335c4fa505affefb63f18a2cb4e62c6f`
- Status: IMPLEMENTED
- Commit / branch: `feat/probe-stop-check`, based on `a10c3843`; its first commit restores the probe withdrawn by `a10c3843`
- Workflow initiative: review-robustness (phase 2, item 1)

## Outcome
- Refusal (AC-1): before any clone, check or test, the probe runs three
  witnesses in its own work directory under the generated read profile,
  each through a child shell: create, remove and rename. A witness that is
  not seen stopped makes it exit 2 with `no write sandbox: a denied
  <operation> does not stop the writer on this macOS; denials cannot be told
  from test failures`, and it removes its work directory. The run records
  `mutation: unavailable`.
- Tests (AC-2): `witnessRefusal` is a pure function, unit-tested on every
  platform. The suite observes a stopped writer once (10 s deadline, each
  `ps` bounded) and runs its integration cases only there; elsewhere it
  runs the refusal case, which asserts the create-witness line and the
  removed work directory.
- Contract (AC-3): implementation-loop step 12, the probe `--help` and
  ADR-0040 name the refusal and the measurement.

## Context
- The probe shipped as `59e2b560` and was withdrawn by `a10c3843`: on
  macOS 14.4, `sandbox-exec` accepts `(with send-signal SIGSTOP)` but a
  denied write returns EPERM without stopping the writer, so a denial
  scored as `killed`. macOS 26 stops the writer. Writes stayed denied on
  both.

## Decisions
### Refuse instead of a weaker detection
- Context: on macOS 14.4 the denied path is not observable, so denials
  cannot be told from test failures.
- Choice: refuse at start-up; the owner accepted that the probe stays
  unavailable on that machine until its macOS stops denied writes.
- Rejected options: EPERM-based detection from test output.
- Consequences: the guarantee is bounded to the three witnessed operations,
  stated in the ADR.

## Accepted Drift
- The witnesses run after the work directory and read profile exist (not
  before any work directory as first drafted), so they exercise the real
  profile and touch only the probe's own files; the plan adversary asked
  for this.

## Validation Evidence
- command: `node --test tests/mutation-probe.test.mjs`
  - result: macmini (macOS 26) 36 tests, 35 pass, 1 skipped (refusal
    case); macbook-work (macOS 14.4) 10 pass, integration skipped.
- command: `node workflow/runtime/mutation-probe.mjs --base HEAD --test true`
  in a scratch repo on macbook-work
  - result: exit 2, the create-witness refusal line, no work directory left.
- command: `scripts/verify-agentic-infra core` and `full`;
  `bun test pi/extensions/__tests__/`; `bash tests/workflow-scaffold-smoke.sh`
  - result: green (core 13/13, Pi 62 pass, smoke ok; `full` on the final
    commit before push).
- Mutation probe on this diff (`--base 53026b21`, unit cases): 0 survived
  of 1.
- Privacy grep against a private term list over every commit: 0.

## Review
- Plan: one cross-model round, CHALLENGED (1 high, 3 medium, 1 low), all
  folded: three witnesses under the generated profile through a child, an
  observed stopped state in the test gate, a pure classification function,
  witnesses confined to the probe's work directory.
- T1: Logic and Spec GO WITH NOTES; adversary BLOCK (1 medium: gate launch
  failures). Folded.
- T2: Logic and Spec GO WITH NOTES; adversary BLOCK (1 medium: unbounded
  `ps`). Folded with a prefix for runner failures.
- D1: Logic GO; adversary BLOCK (1 medium: attempts bounded, not time).
  Folded with one deadline.
- D2: Logic GO; adversary GO WITH NOTES, no findings. Clean.

## Follow-up State
- Remaining risks: a host that stops some operations but not others beyond
  the three witnesses; the test gate checks create only (a host stopping
  create but not rename makes the probe refuse loudly).
- Parking lot: phase-2 items context pack (M2), patch chunking with a
  private bench, proof tests.
- Superseded docs/specs: none.
- Next links: ADR-0040 review on 2027-01-29.
