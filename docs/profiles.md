# Profiles

This guide explains when to use the repo's two explicit profiles.

Canonical profile contracts live in:
- `profiles/README.md`
- `profiles/personal/README.md`
- `profiles/work/README.md`

## Current rule

Profile selection is manual.
There is no automatic loader in this phase.

Use the profile that matches the work context, then keep the shared workflow contract unchanged:
- `workflow/spec.md`
- `workflow/statuses.md`
- `workflow/review-rubric.md`
- `workflow/handoff-template.md`

## Choose `personal`

Use `profiles/personal/` when:
- the task is personal/local
- Pi is the main runtime
- faster iteration matters more than cross-team portability
- local convenience tools are acceptable

Expect:
- Pi-first commands and extensions
- more autonomy inside local safety defaults
- local shell/env context to be acceptable

## Choose `work`

Use `profiles/work/` when:
- the task is work-facing
- Claude is the main runtime
- explicit plans, review, and handoff matter more than local speed
- provider/model and tooling choices need to stay auditable

Expect:
- Claude-first command surfaces
- tighter autonomy and more explicit artifacts
- fewer personal-local assumptions

## What stays shared

Profiles do not change:
- `PLAN_TEMPLATE.md`
- `PLAN.md` statuses
- review rubric structure
- handoff template structure
- the repo workflow entrypoints

## Still manual in this phase

- no profile auto-loading
- no runtime-enforced command allowlists
- no separate per-profile settings engine

Later phases may tighten enforcement only if the manual contract proves too weak.
