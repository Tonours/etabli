# Plan archives

You find the memory of past etabli plans here: one file per plan
that was implemented and validated, plus the record of any root plan
discarded with `scripts/plan-cleanup --discard`. Active work never lives here.
The canonical contract is
[`workflow/plan-archive.md`](../../workflow/plan-archive.md).

## Rules

- Keep active work in the repository root `PLAN.md`.
- Archive a plan only once it is implemented and validated:
  `scripts/plan-cleanup --archive docs/plan/<file>.md` checks the
  `# Implemented:` title, `Status: IMPLEMENTED` and the source plan SHA-256
  before it removes the root plan.
- Name each file `YYYYMMDD-short-slug.md`. A discarded plan becomes
  `YYYYMMDD-discarded-<reason-slug>.md` with `Status: DISCARDED`.
- An archive is immutable once written. A later fix goes in a new commit or a
  new plan.
- No drafts, challenged plans, raw chat logs or backlog ideas here, and no
  `Status: DONE`: finished work is archived, not relabelled.

## Read the archives

- Start with the newest archive when you investigate current workflow
  behavior.
- Treat older archives as decision history unless a current source-of-truth
  file still points to them.
- Prefer the current contracts for execution rules:
  - workflow routing: [`workflow/spec.md`](../../workflow/spec.md)
  - archive format: [`workflow/plan-archive.md`](../../workflow/plan-archive.md)
    and its template
    [`workflow/templates/plan-archive.md`](../../workflow/templates/plan-archive.md)
  - review rules: [`workflow/review-rubric.md`](../../workflow/review-rubric.md)
  - shared skill contracts: [`workflow/skills/`](../../workflow/skills/)
