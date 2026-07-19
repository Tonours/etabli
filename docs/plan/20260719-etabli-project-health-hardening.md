# Implemented: Etabli project health hardening

## Metadata

- Archived: 2026-07-19
- Source plan: Etabli Project Health Hardening
- Status: IMPLEMENTED LOCALLY
- Commit / branch: uncommitted worktree on `main` at baseline `d93ef6f0`
- External state: no push, deploy, or GitHub settings mutation performed

## Outcome

- Made the central CI suite repository-hermetic. Obvault-dependent tests now use
  a tracked deterministic fixture and pass from a copied repository with no
  sibling Obvault checkout.
- Replaced duplicated CI command lists with
  `workflow/runtime/agentic-infra-checks.tsv`, consumed by
  `scripts/verify-agentic-infra`. The manifest now owns syntax/config checks,
  all deterministic shell/docs smokes, the Pi gate, and the Neovim gate.
- Turned the Pi job into a real compile and dependency gate: strict
  `tsc --noEmit`, an intentional-error proof through the configured project
  command, `@earendil-works/pi-coding-agent` 0.80.10, exact tool versions,
  secure transitive overrides, a frozen lockfile, and zero `bun audit`
  advisories.
- Pinned every GitHub Action to a full commit SHA and Hunk to 0.17.3. Added
  weekly Dependabot surfaces for GitHub Actions and `pi/` npm dependencies.
- Added explicit version-2 detail contracts for all 30 workflow events in one
  extracted jq validator. New v2 ledgers keep strict terminal ordering; a
  bounded compatibility path keeps all 40 existing v1 or unversioned ledgers
  readable without rewriting append-only history.
- Separated measured outcomes, explicitly unmeasured outcomes, legacy evidence,
  and multi-model runtime usage. Runtime usage cannot imply outcome success and
  unavailable values remain unknown rather than becoming zero.
- Changed retrospective confidence from raw duplicate evidence to independent
  ledger initiatives. The pre-archive corpus moved from four inflated confirmed
  findings to zero independently recurring findings while retaining 184
  observations for inspection; scanning this archive yields 187 observations
  and still zero confirmed recurrence.
- Centralized the Pi agent npm path across install, deploy, and link repair.
  Replaced predictable Codex audit scratch paths with a private `mktemp` file
  and exit cleanup, covered by concurrent audit smoke tests.

## Context

- `.github/workflows/agentic-infra.yml`: hosted jobs previously duplicated a
  partial local suite, used mutable action tags, and depended on an untracked
  sibling Obvault checkout.
- `pi/package.json` and `pi/bun.lock`: the old Pi package graph produced 23 Bun
  audit advisories and had no TypeScript compiler gate.
- `scripts/workflow-event`: exposed 30 event types but validated only a subset
  of their detail contracts; the multi-execution schema remained a large inline
  exception until fresh review caught it.
- `.workflow/`: historical runs contain sparse telemetry and four legacy
  post-terminal append patterns. They are evidence to read, not history to
  rewrite.
- The pre-existing War Machine handoff changes were treated as user work and
  preserved throughout this implementation.

## Decisions

### Use one executable validation manifest

- Context: local and hosted test lists had diverged and four central smokes were
  absent from CI.
- Choice: keep environment setup in CI jobs and dispatch every deterministic
  check through one tracked TSV manifest and canonical runner.
- Rejected options: another generated workflow, duplicated YAML steps, or an
  external fixture checkout.
- Rationale: parity is inspectable and mechanically tested without introducing
  a generator lifecycle.
- Consequences: adding or removing a canonical check is a manifest change; CI
  contains only setup plus one group call per job.

### Make dependency and compile evidence semantic

- Context: the job named TypeScript verification only ran Bun tests, and the
  dependency graph had compatible security fixes.
- Choice: compile all extension/test TypeScript plus the shared runtime module
  under one strict project, prove failure through exactly `bun run typecheck`,
  pin direct tooling, and use Bun overrides for affected transitives.
- Rejected options: keep ambient declaration shims, run `tsc` on one unrelated
  temporary file, or document fixable advisories as accepted debt.
- Rationale: a green job now demonstrates the property its name claims.
- Consequences: compiler drift, lockfile drift, and known compatible
  vulnerabilities fail the Pi group.

### Keep event compatibility explicit and bounded

- Context: strict new detail contracts must not make historical local evidence
  unreadable, but legacy terminal ordering must not weaken new writes.
- Choice: keep every event detail contract, including
  `multi_execution_completed`, in `scripts/lib/workflow-event-detail.jq`;
  accept post-terminal records only when both the terminal and following record
  are v1 or unversioned.
- Rejected options: rewrite append-only ledgers, exempt multi-execution in the
  shell wrapper, or allow v2 events after a terminal.
- Rationale: one validator owns schema semantics while envelope versioning
  contains historical exceptions.
- Consequences: all current ledgers validate; every new append remains v2 and
  terminal-strict.

### Report uncertainty instead of synthetic improvement

- Context: historical runs rarely contain measured usage/outcomes, and raw
  archive or retry evidence inflated retrospective recurrence.
- Choice: classify evidence independently, compute tokens per successful
  outcome only from usage-measured successful outcomes, and count unique ledger
  initiatives before archive-only sources.
- Rejected options: treat runtime usage as success, replace missing usage with
  zero, or backfill historical measurements.
- Rationale: incomplete evidence remains visible without supporting a false
  efficiency or recurrence claim.
- Consequences: pre-closure measurement coverage remains 4 of 39 terminal runs
  (10.26%), with zero usage-measured successful outcomes and a null
  tokens-per-successful-outcome value.

### Extract only demonstrated operational drift

- Context: path duplication had already caused Pi deployment drift, and the
  Codex audit used predictable process-ID temporary paths.
- Choice: add one small Pi path helper and private audit scratch handling.
- Rejected options: broad decomposition of mature installer/deployer scripts
  based on file length alone.
- Rationale: both seams map directly to reproduced risks and have focused
  regression tests.
- Consequences: larger script decomposition remains a separate evidence-led
  maintenance decision.

## Accepted Drift

- Original plan/spec: every historical ledger should remain readable without
  weakening strict ordering.
- Implemented reality: four v1/unversioned ledgers use a visibly labelled
  compatibility result because they appended evidence after a terminal event;
  all v2 terminal/follower combinations remain rejected.
- Why accepted: the archive is append-only, and version-bounded reading repairs
  compatibility without altering historical evidence or new guarantees.

- Original plan/spec: improve outcome telemetry coverage.
- Implemented reality: classification, validation, and future capture are
  stronger, but historical coverage is not backfilled.
- Why accepted: fabricated token or elapsed values would create false evidence.

- Original plan/spec: close all findings from the repository audit.
- Implemented reality: local code/config findings are closed; vulnerability
  alerts, secret scanning, branch protection, rulesets, push, and hosted CI
  remain untouched.
- Why accepted: these are external writes that require explicit user approval.

## Validation Evidence

- `scripts/verify-agentic-infra all`:
  - result: PASS after the final reviewer fixes; all manifest-owned shell/docs,
    Pi, and Neovim targets are green.
  - result: 219 Pi tests, 610 expectations, 32/32 router evaluations, 20 skill
    hashes, strict typecheck, imports, audit, links, install, and Nvim smokes.
- `cd pi && bun install --frozen-lockfile && bun run typecheck && bun audit`:
  - result: PASS; no install changes and no vulnerabilities found.
- Isolated repository copy without sibling `obvault`:
  - result: PASS; Claude hooks, Obvault query, and 16 resolver/router tests.
- `bash tests/workflow-event-smoke.sh` and all-local-ledger validation loop:
  - result: PASS; all 30 v2 detail fixtures reject a missing required field,
    extensive multi-model v1/v2 invariants pass, v2 post-terminal events fail,
    and 40 local ledgers are readable.
- YAML parse for the CI and Dependabot files plus `git diff --check`:
  - result: PASS.
- `scripts/workflow-retrospect --json` after archive creation:
  - result: 187 observations, zero confirmed independent recurrence.
- Fresh-context reviewer `/root/project_health_fresh_review`:
  - first result: `BLOCK`; all three findings were accepted and fixed.
  - final result: implementation review `GO` and adversary code-diff `GO`, with
    no actionable finding remaining and no reviewer worktree mutation.

## Follow-up State

- Remaining risks: hosted GitHub CI is not proven until this worktree is
  committed and pushed; remote vulnerability alerts, secret scanning, branch
  protection, and rulesets remain disabled or absent; historical outcome
  coverage remains sparse by design.
- Parking lot: enable remote repository protections only after explicit
  approval; collect real measured outcomes in future runs; split larger scripts
  only when a concrete change or failure demonstrates a useful seam.
- Superseded docs/specs: none. The War Machine handoff archive remains the
  preceding implemented record and its worktree changes remain intact.
- Next links: `workflow/runtime/agentic-infra-checks.tsv`,
  `scripts/lib/workflow-event-detail.jq`, `workflow/events.md`,
  `docs/plan/20260719-war-machine-handoff-review.md`, and
  `.github/dependabot.yml`.
