# Workflow Spec

This directory is the canonical workflow contract for `etabli`.

Runtime-owned wrappers still live where the tools expect them:
- Pi commands and skills: `pi/skills/`
- Claude commands: `claude/commands/`
- Installed Claude shared docs: `~/.claude/review-rubric.md`, `~/.claude/handoff-template.md`

This spec defines the shared story those wrappers must follow.

## Operating model

Use `workflow/operating-model.md` for the day-to-day Claude + Pi execution model:
- one main session owns intent and arbitration
- Claude and Pi stay runtime surfaces over the same contract
- the default path is one active mutable checkout
- zero-idle means pipelining review, QA prep, and focused support without unsafe write contention

## Canonical flow

`learn -> phase-0 measure -> plan -> implement -> review -> handoff`

## Contract

1. Learn
   - Read code directly or use `scout` for bounded reconnaissance.
   - Gather only the context needed for the current task.
2. Phase-0 measure
   - Define the minimum measurement contract before a plan can be execution-ready.
   - Capture the expected outcome, blocking checks, trace points, stop/rollback triggers, escalation triggers, and a practical diff budget.
   - Keep this inside `PLAN.md`; do not create a second mandatory artifact.
3. Plan
   - Create or refresh `PLAN.md` from the root `PLAN_TEMPLATE.md`.
   - Start at `Status: DRAFT`.
   - Fill the measurement contract explicitly, not implicitly.
   - Make the plan executable: explicit non-goals, invariants, done criteria, and ordered slices with file scope, checks, and rollback points.
   - Review hardens the same file in place.
4. Implement
   - Implement only from a `READY` `PLAN.md`.
   - Follow the slices in order, not a free-form reinterpretation of intent.
   - For each slice: mark it active, load only the needed context, make the smallest change, run the slice checks, summarize the outcome, then decide whether to continue, correct, or replan.
   - Keep implementation state lightweight and explicit inside `PLAN.md`.
   - Keep scope bounded to the approved plan.
   - If new facts invalidate the plan, update `PLAN.md` first and re-establish `READY`.
5. Review
   - Run a focused review before calling the work done.
   - Review should cover self-check, plan compliance, adversarial review, and human checkpoint triggers.
   - Review checks correctness, regressions, safety, missing validation, and drift from `PLAN.md`.
6. Handoff
   - Use a generic handoff for continuation.
   - Use an implementation handoff when pausing active work from a `READY` plan.

## Shared artifacts

- `PLAN_TEMPLATE.md`
  - Canonical shape for `PLAN.md`
- `PLAN.md`
  - Single execution contract and light progress artifact per task
- `workflow/review-rubric.md`
  - Shared review rubric used by Pi/Claude flows
- `workflow/handoff-template.md`
  - Shared continuation template used by Pi/Claude flows

## Execution rules

- Never implement from `DRAFT` or `CHALLENGED`.
- A plan is not `READY` until its measurement contract is explicit enough to judge success, stop, and escalation.
- A plan is not `READY` until its execution contract is explicit enough to guide implementation slice by slice.
- Planning review never creates `REVIEW.md`; it updates `PLAN.md` in place.
- `plan-loop` and `plan-review` stop at the reviewed plan; they do not continue into implementation and do not ask for implementation confirmation.
- `plan-implement` is the only continuous flow that may go from planning/review straight into implementation once `PLAN.md` is `READY`.
- Keep one workflow story across Pi and Claude; runtime surfaces may differ, contract should not.
- Prefer simple plumbing over hidden automation.
- Multi-agent use should stay bounded: scout/reviewer may parallelize freely, worker stays single by default unless isolation is explicit.
- Prefer simple repo/cwd-based execution over extra launcher plumbing.

## Related docs

- `workflow/operating-model.md`
- `workflow/statuses.md`
- `workflow/review-rubric.md`
- `workflow/handoff-template.md`
- `profiles/README.md`
- `docs/profiles.md`
- `memory/projects/README.md`
