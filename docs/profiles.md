# Profiles

This guide explains when to use the repo's two explicit profiles.

Canonical profile contracts:

- `profiles/README.md`
- `profiles/personal/README.md`
- `profiles/work/README.md`

## Current rule

Profile selection is manual. There is no automatic loader.

Profiles do not change the workflow contract:

- `workflow/spec.md`
- `workflow/review-rubric.md`
- `workflow/handoff-template.md`

## Choose `personal`

Use `profiles/personal/` when the task is personal/local and Pi-first speed matters more than portability.

Expect local convenience tools and more autonomy inside local safety defaults.

## Choose `work`

Use `profiles/work/` when the task is work-facing and auditability matters.

Expect Claude-first command surfaces, explicit review, and fewer personal-local assumptions.

## Shared invariants

Profiles do not change:

- `PLAN.md` status model
- review rubric structure
- handoff template structure
- repo workflow entrypoints
