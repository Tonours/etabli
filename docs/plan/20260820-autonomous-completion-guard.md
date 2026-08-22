# Implemented: autonomous completion preflight and lock binding

## Metadata
- Archived: 2026-08-20
- Source plan: `PLAN.md` — Prevent premature autonomous completion
- Source plan SHA-256: `4e45c63101506256abe879057a500f08de3343d276282f1b0e517411aa80ee72`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `refactor/skill-default-load`

## Outcome
- A schema-v2 run that ever selects `plan-implement` cannot append `completed`
  until the exact candidate ledger passes `autonomous-completed`.
- Missing evidence leaves the canonical ledger bytes and active pointer unchanged;
  adding the missing evidence lets the same run complete normally.
- Native writers bind authority to a trusted `lockf`/`flock` process locking FD 9,
  whose inode must remain the current canonical `events.lock` at initial and
  immediate pre-append proof points.
- Legacy/schema-v1 and non-autonomous completion behavior remains compatible.

## Context
- The prior `etabli-evidence-program` run appended its terminal event before an
  `outcome_metric`, making the immutable ledger structurally valid but invalid
  under `autonomous-completed`.
- That ledger remains unchanged at SHA-256
  `824f45ee92ff2810f1ea335f83397762b08030005ce93f83763b7b32e381fa64`,
  15,157 bytes, 52 lines, terminal `completed`, and zero `outcome_metric` events.

## Decisions

### Validate the exact terminal candidate before canonical append
- Context: validating only after append cannot repair an append-only terminal
  ledger with missing prerequisites.
- Choice: render one terminal line, validate a temporary candidate under the
  run directory with the canonical measurement root, then append that same line.
- Rejected options: rewriting prior events; exposing a public candidate-file
  override; duplicating profile logic.
- Rationale: failure is byte-preserving and cross-ledger measurements still
  resolve against the canonical workflow root.
- Consequences: autonomous completion is fail-closed without changing structural
  compatibility for other routes.

### Bind native lock authority to process, descriptor, and inode
- Context: parent command names, caller-owned capability files, open descriptors,
  and global contention were individually forgeable or composable.
- Choice: use fixed non-symlink system tools, verify the real native executable,
  canonical cwd and argv, lock pre-opened FD 9, and prove FD 9 resolves to the
  current canonical inode before work and immediately before append.
- Rejected options: JSON capabilities; open-FD proof alone; pathname-only locks;
  claims of hostile same-UID security.
- Rationale: this closes the reproduced wrong-lock, inherited-FD, forged-PATH,
  and observable pathname-replacement cases without a new dependency.
- Consequences: the contract is an integrity boundary for cooperative writers.
  A same-UID actor mutating files or processes inside the final syscall interval
  remains explicitly outside the boundary.

## Accepted Drift
- Original plan/spec: two bounded repair rounds.
- Implemented reality: adversarial repair continued until both independent
  implementation reviews returned `GO`.
- Why accepted: the additional rounds closed concrete reproduced bypasses and
  introduced no task, plan, output, or model-token ceiling.

## Validation Evidence
- `scripts/verify-agentic-infra full`:
  - passed through the final manifest check; includes 192 Pi tests, 53/53 router
    evaluations, 79 verified skill hashes, and all workflow/ledger smokes.
- `tests/autonomous-ledger-hygiene-smoke.sh`:
  - passed missing-evidence refusal, exact-byte success, compatibility,
    cross-ledger measurement, concurrency/race, wrong-lock/inherited-FD,
    forged-PATH, and pathname-replacement fixtures.
- `tests/workflow-event-smoke.sh` and `tests/program-state-smoke.sh`:
  - passed; 128-unit replay remained deterministic and 128 locked appends used
    the native `lockf` backend.
- `git diff --check`:
  - passed.
- Independent reviews:
  - code-diff adversary `GO`; fresh cumulative reviewer `GO` with all deciding
    behaviors covered.

## Follow-up State
- Remaining risks: live macOS behavior is exercised locally; Linux `/proc` and
  `flock` behavior is covered by the portable branch and CI/smoke environment,
  but hostile same-UID mutation is not a supported security boundary.
- Parking lot: none for this corrective slice.
- Superseded docs/specs: none; `workflow/events.md` contains the live contract.
- Next links: `docs/plan/20260820-etabli-evidence-program.md`.
