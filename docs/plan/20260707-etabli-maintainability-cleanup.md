# Implemented: Etabli maintainability cleanup

## Metadata
- Archived: 2026-07-07
- Source plan: Etabli maintainability cleanup
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `main`

## Outcome
- Added `docs/plan/README.md` as the local map for implemented-plan archives.
- Linked the archive map from the root `README.md`.
- Added `tests/workflow-docs-smoke.sh` coverage so the local archive map exists
  and points to the canonical `workflow/plan-archive.md` contract.
- Removed the empty, untracked top-level `plans/` directory with `rmdir`.

## Context
- `workflow/plan-archive.md` is the canonical archive contract.
- Scaffolded projects already receive a `docs/plan/README.md` from
  `workflow-scaffold/templates/docs/plan.md`, but this repo did not have a
  tracked local index for its own archive directory.
- `plans/` was empty, untracked, and had no live `plans/` references from `rg`.
- `docs/plan/20260707-obvault-second-brain.md` existed before this cleanup as
  an untracked archive and was preserved.

## Decisions

### Add a map, not a second archive contract
- Context: duplicating archive rules would make future drift more likely.
- Choice: keep `docs/plan/README.md` short and name
  `workflow/plan-archive.md` as the canonical contract.
- Rejected options: copy the full archive contract into `docs/plan/README.md`;
  list every archive file as maintained metadata.
- Rationale: the directory needs a local entry point, but execution rules should
  stay in one source of truth.
- Consequences: archive browsing is easier without adding a competing contract.

### Remove only the empty untracked `plans/` directory
- Context: `plans/` looked like an old or accidental top-level planning surface.
- Choice: delete it only through `rmdir`, after confirming it had no contents.
- Rejected options: add a heavy guard for `plans/`; leave the empty directory in
  place.
- Rationale: Git does not track empty directories, and no evidence showed it as
  an intentional surface.
- Consequences: root navigation is cleaner; no tracked file changed for this
  deletion.

## Accepted Drift
- Original plan/spec: run a fresh-context review when available.
- Implemented reality: review stayed local because the available subagent tool
  requires explicit user authorization for delegation in this session.
- Why accepted: the diff is small, docs/test-only, and validation covered the
  intended contract.

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed; `workflow docs smoke test: ok`
- command: `bash tests/codex-organization-smoke.sh`
  - result: passed; `codex organization smoke test: ok`
- command: `scripts/audit-codex-organization`
  - result: passed; `codex organization audit: ok`
- command: `git diff --check`
  - result: passed with no output for the tracked diff
- command: `grep -n '[[:blank:]]$' docs/plan/README.md docs/plan/20260707-etabli-maintainability-cleanup.md`
  - result: passed with no trailing whitespace in new untracked files
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed again after archiving; `workflow docs smoke test: ok`

## Follow-up State
- Remaining risks: the archive map can become stale if it starts listing
  per-file metadata; keep it high-level.
- Parking lot: none.
- Superseded docs/specs: none.
- Next links:
  - `docs/plan/README.md`
  - `workflow/plan-archive.md`
