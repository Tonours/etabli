# Workflow Spec

This directory is the canonical workflow contract for `etabli`.

Runtime-owned wrappers still live where the tools expect them:
- Pi commands and skills: `pi/skills/`
- Claude commands: `claude/commands/`
- Installed Claude shared docs: `~/.claude/review-rubric.md`, `~/.claude/handoff-template.md`

This spec defines the shared story those wrappers must follow.

## Canonical flow

`learn -> plan -> implement -> review -> handoff`

## Contract

1. Learn
   - Read code directly or use `scout` for bounded reconnaissance.
   - Gather only the context needed for the current task.
2. Plan
   - Create or refresh `PLAN.md` from the root `PLAN_TEMPLATE.md`.
   - Start at `Status: DRAFT`.
   - Review hardens the same file in place.
3. Implement
   - Implement only from a `READY` `PLAN.md`.
   - Keep scope bounded to the approved plan.
   - If new facts invalidate the plan, update `PLAN.md` first and re-establish `READY`.
4. Review
   - Run a focused review before calling the work done.
   - Review checks correctness, regressions, safety, and missing validation.
5. Handoff
   - Use a generic handoff for continuation.
   - Use an implementation handoff when pausing active work from a `READY` plan.

## Shared artifacts

- `PLAN_TEMPLATE.md`
  - Canonical shape for `PLAN.md`
- `PLAN.md`
  - Single pre-implementation artifact per worktree/task
- `workflow/review-rubric.md`
  - Shared review rubric used by Pi/Claude flows
- `workflow/handoff-template.md`
  - Shared continuation template used by Pi/Claude flows

## Execution rules

- Never implement from `DRAFT` or `CHALLENGED`.
- Planning review never creates `REVIEW.md`; it updates `PLAN.md` in place.
- Keep one workflow story across Pi and Claude; runtime surfaces may differ, contract should not.
- Prefer simple plumbing over hidden automation.
- Worktree/tmux plumbing (`scripts/cw`, `scripts/cw-clean`) stays the repo entrypoint; agent roles sit on top of it.

## Related docs

- `workflow/statuses.md`
- `workflow/review-rubric.md`
- `workflow/handoff-template.md`
- `profiles/README.md`
- `docs/profiles.md`
- `memory/projects/README.md`
