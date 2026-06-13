# Implemented: plan archives for implemented work

## Metadata
- Archived: 2026-06-12
- Source plan: Archiver les plans implementes dans `docs/plan/`
- Status: IMPLEMENTED
- Commit / branch: branch `main`, commit not created yet

## Outcome
- Added a canonical implemented-plan archive convention in `workflow/plan-archive.md`.
- Added the deployed `docs/plan/README.md` template at `harness/templates/docs/plan.md`.
- Updated plan templates so every plan can record archive state and simple plans can record decisions.
- Updated Pi skills and Claude commands so planning never archives and implementation archives only after checks.
- Updated the harness deploy script, root README, workflow spec, and harness AGENTS/CLAUDE templates to expose the convention.
- Extended smoke tests to lock the new workflow and deployed files.

## Context
- `workflow/spec.md`: `PLAN.md` remains the only execution artifact while work is in progress.
- `workflow/memory.md`: `docs/agent-memory/` already exists for reusable lessons, so plan archives needed a separate role.
- User decision from 2026-06-12: archives belong in `docs/plan/` if and only if the plan was implemented.
- `PLAN_TEMPLATE_FULL.md` already had a `Decision Log`; `PLAN_TEMPLATE.md` did not.

## Decisions
### Use `docs/plan/` for implemented plan history
- Context: the user explicitly requested `/docs/plan`.
- Choice: use the singular `docs/plan/` path and document that the singular name is intentional.
- Rejected options: `docs/plans/`; storing implemented plans in `docs/agent-memory/`.
- Rationale: following the requested path avoids hidden renaming, and plan history is distinct from reusable behavioral lessons.
- Consequences: future cleanup should not rename the directory without an explicit decision.

### Archive only after implementation and validation
- Context: drafts, challenged plans, and abandoned ready plans can contain intent that never became project truth.
- Choice: planning commands explicitly do not create or update `docs/plan/`; implementation commands archive only after focused checks complete.
- Rejected options: archive every `PLAN.md` as soon as it is created; archive `READY` plans before implementation.
- Rationale: the archive should preserve implemented reality, not speculative planning state.
- Consequences: the rule is primarily behavioral; smoke tests verify instruction presence but do not prove every future agent obeys it.

### Distill archives instead of raw-copying `PLAN.md`
- Context: execution plans contain transient scaffolding, stale assumptions, progress noise, and rollback notes.
- Choice: require a memory-first implementation record with outcome, context, decisions, accepted drift, validation evidence, and follow-up state.
- Rejected options: raw copy of `PLAN.md`; full ADR replacement.
- Rationale: future agents need why choices were made and what evidence made them trustworthy, not a run log.
- Consequences: writing an archive costs a little more effort but should remain short and high-value.

## Accepted Drift
- Original plan/spec: validation initially said to inspect that no archive file other than `docs/plan/README.md` was created.
- Implemented reality: this implementation created `docs/plan/20260612-implemented-plan-archives.md` after checks passed.
- Why accepted: it resolves a contradiction in the plan and applies the new rule to this implemented plan itself.

## Validation Evidence
- command: `bash tests/workflow-docs-smoke.sh`
  - result: passed, output `workflow docs smoke test: ok`
- command: `bash tests/harness-smoke.sh`
  - result: passed, output `harness smoke test: ok`
- command: `git diff --check`
  - result: passed with no output
- command: `scripts/deploy-harness /tmp/etabli-plan-archive-dry-run --dry-run`
  - result: passed and listed `docs/plan/README.md` plus `workflow/plan-archive.md`

## Follow-up State
- Remaining risks: the "if and only if implemented" rule is instruction-driven, not mechanically enforced by a dedicated validator.
- Parking lot: add a future linter that rejects archive files without `Status: IMPLEMENTED` and `Validation Evidence`.
- Superseded docs/specs: none.
- Next links: current `PLAN.md` and `workflow/plan-archive.md`.
