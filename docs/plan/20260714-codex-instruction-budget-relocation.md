# Implemented: Relocated Codex rules within the strict instruction budget

## Metadata
- Archived: 2026-07-14
- Source plan: Relocate Codex workflow rules without exceeding the instruction budget
- Status: IMPLEMENTED
- Branch: `main` working tree before the authorized whole-worktree commit

## Outcome
- Preserved four user-authored workflow/safety rules covering shell/cwd recovery,
  scoped external research, explicit repository-change verdicts, and mutable
  local-device/server preflight.
- Moved those harness-neutral rules from the always-read `codex/AGENTS.md` into
  the canonical `workflow/spec.md` contract already referenced by the Codex
  adapter.
- Added documentation smoke assertions for every relocated rule intent.
- Restored the strict instruction budget to 1,888 estimated tokens against the
  1,891-token stretch limit (19.97% of the 9,455-token baseline).
- Unblocked the complete shell/docs and Pi verification groups without changing
  their thresholds.

## Context
- The pre-push whole-worktree gate reported 2,047 estimated tokens and failed
  `workflow-efficiency-report-smoke`.
- An isolated run proved the pi-workflow integration was not the primary cause;
  the 636-character `codex/AGENTS.md` addition occupied an always-read surface.
- `codex/AGENTS.md` already directs Codex to `workflow/spec.md`, so canonical
  relocation preserves discoverability while reducing permanent context cost.

## Decisions

### Preserve semantics through canonical relocation
- Context: the user explicitly authorized committing the whole worktree, so the
  red budget could not be dismissed as an unrelated local change.
- Choice: move all four rules to `workflow/spec.md` and restore the compact
  adapter file.
- Rejected options: delete the rules, weaken the stretch target, or push with a
  known red relevant group.
- Rationale: shared workflow and safety behavior belongs in the shared contract;
  adapters should stay thin.
- Consequences: the rules apply consistently across Etabli runtimes and are
  mechanically pinned outside the always-read budget set.

## Accepted Drift
- The original user edit targeted `codex/AGENTS.md`; the implemented location is
  `workflow/spec.md`. This location change is intentional because the behavior
  is harness-neutral and the adapter already names the spec as a source.
- The supervised publish repair used same-model review/adversary passes; no
  subagent or fresh-context reviewer was authorized for this narrow pre-push fix.

## Validation Evidence
- `bash tests/workflow-efficiency-report-smoke.sh`: PASS.
- `scripts/verify-agentic-infra shell-docs`: PASS.
- `scripts/verify-agentic-infra pi`: PASS, including 204 Pi tests.
- `scripts/workflow-efficiency-report --json`: 1,888/1,891 estimated tokens,
  ratio 0.19968, `within_stretch_target:true`.
- `git diff --check`: PASS.
- Supervised same-model review: `GO`, no findings.
- Supervised adversary code-diff pass: `GO`, no accepted findings or surviving
  blockers.

## Follow-up State
- Remaining risks: instruction-budget headroom is only three estimated tokens;
  future always-read additions should replace or relocate text rather than grow
  adapter files.
- Parking lot: none.
- Superseded docs/specs: the temporary expanded `codex/AGENTS.md` wording is
  superseded by `workflow/spec.md`.
- Next links: `workflow/spec.md`, `scripts/workflow-efficiency-report`, and
  `tests/workflow-efficiency-report-smoke.sh`.
