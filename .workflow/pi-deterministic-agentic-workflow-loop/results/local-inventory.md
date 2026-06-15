# Local Inventory

## Confirmed Local Facts

- `AGENTS.md` maps the repo and names `workflow/spec.md`,
  `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`, and `workflow/review-rubric.md`
  as workflow sources of truth.
- `pi/AGENTS.md` already encodes the desired operator style: French, concise,
  evidence-first, small reversible steps, focused checks, preserve unrelated
  changes, and do not bypass Pi guardrails.
- `workflow/spec.md` defines the canonical loop:
  `learn -> plan -> implement -> review -> validate`.
- `workflow/spec.md` defines `PLAN.md` statuses as `DRAFT`, `CHALLENGED`, and
  `READY`; only `READY` authorizes implementation.
- `PLAN_TEMPLATE.md` and `PLAN_TEMPLATE_FULL.md` already require goal, scope,
  observed facts vs assumptions, checks, risks, decisions, questions, and
  handoff state.
- `pi/agent/settings.json` loads local Pi extensions:
  `rtk.ts`, `filter-output.ts`, `block-google-providers.ts`, and
  `tasks-till-done.ts`.
- `pi/agent/settings.json` loads local Pi skills:
  `plan-loop`, `plan-implement`, `review`, `implement`, `caveman`, and
  `grill-me`.
- `pi/skills/plan-loop/SKILL.md` plans and reviews only; it must not implement
  or create archives.
- `pi/skills/plan-implement/SKILL.md` runs planning first, implements only when
  `PLAN.md` is `READY`, archives implemented plans, and deletes the root
  `PLAN.md` after successful archive and validation.
- `pi/skills/implement/SKILL.md` implements an existing `READY` `PLAN.md`
  without rerunning full planning.
- `pi/skills/review/SKILL.md` is read-only and reports actionable findings
  grounded in the current diff.
- `pi/extensions/tasks-till-done.ts` appends hidden task-loop guidance when
  Task* tools are active and the prompt is action-oriented.
- `tasks-till-done` auto-continues only while `TaskList` shows actionable open
  tasks; it stops on completion, blocked tasks, repetition, inactivity, or a
  max auto-continue limit.
- `workflow-scaffold/templates/docs/agent-workflow.md` explains the portable
  project workflow scaffold.
- `workflow-scaffold/templates/docs/claude-code-workflow.md` already contains a
  useful planner / builder / evaluator reference model, but it is Claude-facing
  and should be adapted carefully for Pi.

## Current Gaps

- No single Pi-native document defines the deterministic agentic loop as a
  product/system.
- Routing rules are implicit across skills instead of explicit and testable.
- Planner/challenger/implementer/verifier/reporter are behaviors spread across
  skills, not named role contracts.
- `tasks-till-done` continues task execution, but it does not yet know workflow
  phases or required validation evidence.
- There is no prompt/fixture eval suite for "when user says X, Pi should use
  role Y and stop under condition Z".
- There is no dedicated verifier skill. Validation exists inside plan and
  implementation skills, but not as a reusable role.

## Design Implication

The next layer should not replace Pi. It should make the existing Pi surface
more explicit:

- document the loop;
- make role contracts visible;
- add a small router contract;
- add focused skills/templates where gaps exist;
- enhance extensions only where mechanical enforcement is useful;
- add local fixture tests to catch routing and stop-condition drift.
