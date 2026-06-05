# Claude Code Harness

Source: Anthropic, "Harness design for long-running application development", published March 24, 2026.

## Default Rule

Use the simplest workflow that can reliably finish the task.

For normal bugfixes and features, use:

```text
plan -> implement -> review -> validate
```

Do not add multi-agent overhead by default. Add planner/builder/evaluator separation only when the task is long-running, UI-heavy, subjective, broad, or beyond what a single Claude Code session can reliably verify.

## Failure Modes to Guard Against

- Long tasks lose coherence as context fills.
- Agents may wrap up early when they sense context pressure.
- Self-evaluation is too generous, especially for UI quality and product completeness.
- Superficial QA misses edge cases and stubbed core behavior.
- Over-specific planning can cascade wrong implementation details.

## Roles

### Planner

Use a planner when the prompt is short, broad, or product-shaped.

The planner produces:

- product intent
- user stories
- acceptance criteria
- high-level technical direction
- explicit non-goals
- validation strategy

The planner should not over-specify low-level implementation details unless the repo already imposes them.

### Builder

The builder implements against the current plan or contract.

The builder should:

- work in small coherent slices
- update `PLAN.md` when facts change
- run focused checks before handoff
- leave exact verification commands and results
- avoid treating its own review as final approval

### Evaluator

Use a separate evaluator for risky work or when the builder cannot produce convincing evidence alone.

The evaluator should be skeptical and concrete:

- test the running app when possible
- use browser automation or Playwright for UI flows
- check APIs, persistence, auth, queues, and external boundaries when touched
- compare behavior against acceptance criteria
- fail the work when core interactions are stubbed, display-only, or incomplete
- report findings with file, line, reproduction, and expected behavior

## Sprint Contracts

For broad or ambiguous work, create an explicit contract before implementation. Skip this for straightforward bugfixes and small features.

Recommended file:

```text
docs/agent-runs/<slug>/contract.md
```

Contract shape:

```md
# Contract

## Slice

## Done Means
- [ ] ...

## Verification
- command:
- manual/UI flow:

## Risks

## Out of Scope
```

The builder proposes the contract. The evaluator challenges it before code is written.

## Handoff Artifacts

When context is getting crowded, stop and write a handoff before resetting.

Recommended file:

```text
docs/agent-runs/<slug>/handoff.md
```

Handoff shape:

```md
# Handoff

## Objective

## Current State

## Files Changed

## Decisions Made

## Validation Run

## Known Failures

## Next Action
```

The next session should read the handoff, inspect the repo state, then continue from the next action. Do not rely on conversation memory.

## UI Evaluation Criteria

For UI work, evaluate separately from implementation:

- design quality: coherent whole, not assembled fragments
- originality: avoids generic templates and default component slop
- craft: typography, spacing, contrast, color, responsiveness
- functionality: users can complete core tasks without guessing

Use screenshots and interactive browser checks when available.

## Complexity Budget

Start with:

```text
single agent -> plan -> implement -> review -> validate
```

Escalate to:

```text
planner -> builder -> evaluator -> builder fixes -> evaluator signoff
```

only when the simpler loop is likely to miss scope, product quality, or verification depth.

Remove or ignore harness pieces that are not adding evidence for the current task.
