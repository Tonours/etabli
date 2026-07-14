# Implemented: Explicit-use Pi workflow graph adapter

## Metadata
- Archived: 2026-07-14
- Source plan: Explicit-use `pi-workflow` adapter for executable named workflow graphs
- Status: IMPLEMENTED
- Branch: `main` working tree at `26e91f3` (not committed or pushed)

## Outcome
- Added the exact `npm:@agwab/pi-workflow@0.8.1` pin to the tracked Pi
  bootstrap, filtered to its extension plus `workflow-guide` and
  `execution-router` skills.
- Reconciled unpinned and superseded package sources without removing similarly
  named user packages.
- Added an explicit-use adapter contract covering state ownership, delegation,
  read-only pilots, Node.js requirements, and the absence of OS isolation.
- Added `supports_named_workflow_graphs` independently from Pi Task* state and
  kept its Pi label `proxy_supported` until a live runtime proof exists.
- Added typed `runtime_run_attached` evidence so an Etabli ledger can link, but
  not replace itself with, `.pi/workflows/<run-id>/` artifacts.
- Added configuration, migration, event-schema, capability, and documentation
  regression checks.

## Context
- Upstream `pi-workflow` provides named single/foreach/reduce/loop/DAG/dynamic
  workflow graphs, persistent run artifacts, stop/resume, usage tracking, and
  bundled review/research workflows.
- Etabli already owned the canonical READY gate, root `PLAN.md`, append-only
  `.workflow` ledger, adversarial review, and Pi Task* capability claims.
- Pi packages and pi-workflow helpers/controllers execute with Pi process
  permissions; upstream `readOnly` is a classification signal, not a sandbox.
- The worktree already contained an unrelated `codex/AGENTS.md` modification;
  it was preserved and excluded from this change and its review.

## Decisions

### Use a thin exact-pin adapter
- Context: the upstream engine is substantial and independently maintained.
- Choice: consume release `0.8.1` through Pi's package mechanism and select only
  its documented extension and skills.
- Rejected options: vendor/fork the engine or copy its orchestration runtime.
- Rationale: preserve upstream ownership while keeping Etabli responsible for
  planning, permissions, validation, and completion evidence.
- Consequences: later upgrades require an intentional pin change and renewed
  config/live-runtime proof.

### Keep Etabli state canonical
- Context: pi-workflow writes detailed runtime state under `.pi/workflows/`.
- Choice: keep `PLAN.md` as the only active implementation plan and
  `.workflow/<slug>/events.jsonl` as canonical progress evidence; attach only a
  strict repository-relative runtime pointer.
- Rejected options: import upstream state as a second plan or task ledger.
- Rationale: avoid competing sources of truth and preserve existing Etabli
  completion gates.
- Consequences: a live run must append `runtime_run_attached` explicitly.

### Make execution opt-in, not ambient
- Context: the tracked bootstrap will reconcile and load the package during a
  future Etabli install/deploy, so package installation itself is not optional.
- Choice: prohibit ambient launch and initially approve only explicitly
  requested bundled `spec-review` and `impact-review` workflows whose loaded
  specs declare `readOnly: true`.
- Rejected options: automatic routing, default dynamic workflows, and a local
  wrapper presented as a sandbox.
- Rationale: named graphs can improve evidence without silently authorizing
  delegation, mutation, or unsandboxed helper code.
- Consequences: mutable/dynamic workflows remain behind READY, permission,
  review, budget, and stop-condition gates.

## Accepted Drift
- No live Pi package install, `/workflow validate`, or pilot run was performed;
  repository-only configuration evidence justifies `proxy_supported`, not
  `confirmed`.
- The final adversary code-diff pass used the supervised same-model substitute
  permitted by the contract after the independent fresh-context reviewer. A
  broader shell/docs gate then exposed excess always-read wording; the Pi rule
  was compressed without changing its invariant and the reviewer approved the
  delta as `GO WITH NOTES` with no findings.

## Validation Evidence
- `cd pi && bun test ./extensions/__tests__/settings-consistency.test.ts`: 5
  passed, 0 failed.
- `bun test pi/extensions/__tests__/`: 204 passed, 0 failed.
- `bash tests/deploy-agent-workflow-smoke.sh`: PASS, including legacy-source
  migration and preservation of a similarly named user package.
- `bash tests/install-smoke.sh`: PASS, including installer reconciliation.
- `bash tests/workflow-event-smoke.sh`: PASS, including valid and malformed
  runtime attachments.
- `bash tests/runtime-capabilities-smoke.sh`: PASS.
- `bash tests/workflow-contract-coverage-smoke.sh`: PASS.
- `bash tests/workflow-docs-smoke.sh`: PASS.
- `bash tests/codex-organization-smoke.sh`: PASS.
- Shell syntax, JSON parsing, and `git diff --check`: PASS.
- `workflow-efficiency-report-smoke` in an isolated worktree containing this
  implementation but excluding the pre-existing `codex/AGENTS.md` user edit:
  PASS. The current mixed worktree remains over the stretch budget because of
  that preserved unrelated edit.
- Fresh-context reviewer `/root/pi_workflow_final_review`: initial `GO`; final
  delta `GO WITH NOTES`; no findings in either pass.
- Final supervised adversary code-diff verdict: `GO WITH NOTES`; accepted the
  instruction-budget simplification, rejected the unrelated local budget
  failure as a blocker, and found no surviving implementation blocker.

## Follow-up State
- Remaining risks: the third-party package still has Pi process access, and
  actual discovery/execution remains unverified until an explicitly authorized
  read-only pilot is run with Node.js `>=22.19.0`.
- Parking lot: live `/workflow list`, `/workflow validate spec-review`, one
  read-only pilot, usage attachment, and promotion to `confirmed` only if all
  recorded proof succeeds.
- Superseded docs/specs: none.
- Next links: `workflow/pi-workflow-adapter.md`,
  `workflow/runtime-capabilities.json`, and `workflow/events.md`.
