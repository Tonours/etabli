# Workflow Spec

Canonical workflow contract for `etabli`.

## Flow

```text
learn -> plan -> implement -> review -> validate
```

## Agentic workflow loop

Pi remains the primary user-facing tool. The deterministic layer is a set of
visible role contracts, templates, skills, extensions, checks, and stop
conditions composed inside Pi. Do not replace Pi with an external wrapper.

Use the smallest workflow that can finish with evidence:

```text
user intent -> router -> planner -> challenger -> implementer -> verifier -> reviewer -> reporter -> stop
```

Roles are contracts, not mandatory separate agents:

- `router`: classify the request into the smallest valid workflow.
- `planner`: create or refresh `PLAN.md` and stop at `READY` or `CHALLENGED`.
- `challenger`: reject vague scope, missing checks, hidden assumptions, and weak
  stop conditions before implementation.
- `implementer`: execute only a `READY` plan, in order, with minimal drift.
- `verifier`: prove or reject completion from checks, artifacts, sources, or
  command output without editing.
- `reviewer`: inspect diff correctness, regressions, safety, validation, and
  plan drift without editing.
- `reporter`: leave durable state through final handoff and implemented plan
  archives when applicable.

## Statuses

`PLAN.md` uses one status:

- `DRAFT`: plan exists, not implementation-ready.
- `CHALLENGED`: review found blockers or vague scope/checks.
- `READY`: scope, steps, checks, and risks are clear enough to execute.

Only `READY` authorizes implementation.

## Rules

- Read code directly before planning or editing.
- Keep one execution artifact: `PLAN.md`.
- Archive implemented plans in `docs/plan/` only after implementation and validation.
- Do not create `REVIEW.md` or secondary mandatory planning docs.
- For small safe tasks, use the simple `PLAN_TEMPLATE.md` shape.
- For broad/risky work, use `PLAN_TEMPLATE_FULL.md`.
- Keep observed facts separate from assumptions in plans.
- Record exact validation commands and results before claiming completion.
- Record route, role, stop condition, and required evidence in non-trivial plans.
- Planning review updates `PLAN.md` in place.
- Implementation follows plan steps in order.
- Implementation commands archive the final implemented plan as a distilled memory record, not a raw `PLAN.md` copy.
- If new facts invalidate the plan, update it before continuing.
- If new facts materially invalidate the implementation route or checks, stop as
  plan drift instead of silently continuing.
- Review checks correctness, regressions, safety, validation, and plan drift.
- Prefer focused checks over full-suite ritual.

## Minimal READY gate

A plan is `READY` when it has:

- clear goal
- bounded scope and non-goals when needed
- concrete steps
- named files/areas for risky changes
- checks to run
- route, role, stop condition, and required evidence for non-trivial work
- known risks or explicit "none"
- facts separated from assumptions when the task depends on uncertain context
- no blocking open questions

## Routing rules

| Trigger | Route | Artifact | Stop |
| --- | --- | --- | --- |
| Simple question or explanation | `answer` | none | answer delivered |
| Broad task, unclear implementation, or "fais un plan" | `plan-loop` | `PLAN.md` | `READY` or `CHALLENGED` |
| Existing `READY PLAN.md` plus implementation request | `implement` | code/docs + archive | validated archive and root `PLAN.md` deleted |
| "plan puis implémente" or equivalent | `plan-implement` | `PLAN.md` then code/docs | validated archive and root `PLAN.md` deleted |
| Create or draft a Linear ticket | `linear-ticket-create` | Linear issue | created issue or MCP blocker |
| Analyze a Linear bug without implementing | `bug-check` | adversarial root-cause report | `CERTAIN`, `HIGH CONFIDENCE`, or `UNCERTAIN` |
| Bug fix or feature described by Linear ticket | `linear-work` | `PLAN.md` + code/docs + validation | ticket acceptance criteria validated or blocked |
| GitHub PR code review | `pr-review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| GitHub PR QA plan | `pr-qa` | QA impact plan | executable test plan delivered |
| Dependabot/security PR audit | `sec-pr` | security audit report | `PASS`, `FAIL`, or `INVESTIGATE` |
| Explicit autonomous CI repair | `ci-fix` | commits/pushes + CI report | CI green, blocked, time cap, or max attempts |
| Review request | `review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| Verify, retest, prove, or completion audit | `verify` | verification report | `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE` |
| Research with sources | `research-plan` | cited doc under `docs/` | cited artifact complete |
| Destructive, secret, production, billing, deployment, or broad irreversible work | `ops-stop` | risk brief | user decision |
| Task tools active and actionable request | `tasks-till-done` assists selected route | TaskList | all tasks done, blocked, stalled, or limit |

## Runtime surfaces

Pi and Claude wrappers are thin runtime adapters over this contract.

- Pi skills: `pi/skills/`
- Claude commands: `claude/commands/`
- Claude optional hooks: `claude/hooks/` with
  `claude/settings.workflow-hooks.json`
- Plan templates: `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`
- Implemented plan archives: `docs/plan/` in workflow-scaffolded projects (`workflow/plan-archive.md`)
- Project context: `docs/project-context.md` in workflow-scaffolded projects
- Agent memory: `docs/agent-memory/` in workflow-scaffolded projects (`workflow/memory.md`)
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Linear ticket template: `workflow/linear-ticket-template.md`

## Default commands

Pi:

- `/skill:plan-loop <task>`: create/review `PLAN.md`, stop at `READY` or `CHALLENGED`
- `/skill:plan-implement <task>`: plan, then implement if `READY`
- `/skill:implement`: implement existing `READY` plan
- `/skill:review`: review current diff
- `/skill:verify`: verify checks, claims, or current work without editing
- `/skill:bug-check`: analyze Linear bug root cause without editing
- `/skill:linear-ticket-create`: create Linear tickets through Linear MCP
- `/skill:linear-work`: work from Linear tickets through Linear MCP
- `/skill:pr-review`: review GitHub PRs through `gh`
- `/skill:pr-qa`: create PR QA test plans through `gh`
- `/skill:sec-pr`: audit Dependabot/security PRs through `gh`
- `/skill:ci-fix`: explicitly requested autonomous CI repair through `gh`
- `/skill:github-pr-review`: compatibility alias for `pr-review`

Claude:

- `/plan`: create `PLAN.md` only, stop at `DRAFT`
- `/plan-loop`: create/review `PLAN.md`, stop at `READY` or `CHALLENGED`
- `/plan-implement`: plan, then implement if `READY`
- `/implement`: implement existing `READY` plan
- `/review`: review current diff
- `/verify-workflow`: verify checks, claims, or current work without editing
- `/bug-check`: analyze Linear bug root cause without editing
- `/linear-ticket-create`: create Linear tickets through Linear MCP
- `/linear-work`: work from Linear tickets through Linear MCP
- `/pr-review`: review GitHub PRs through `gh`
- `/pr-qa`: create PR QA test plans through `gh`
- `/sec-pr`: audit Dependabot/security PRs through `gh`
- `/ci-fix`: explicitly requested autonomous CI repair through `gh`
- `/github-pr-review`: compatibility alias for `/pr-review`

Claude-native loop:

- Use `/goal <measurable condition>` for long-running completion loops instead
  of recreating Pi's Task* continuation layer.
- Use `claude/settings.workflow-hooks.json` as an opt-in settings fragment for
  routing context and READY-gate hook enforcement.

## Daily loop

1. inspect repo state
2. read relevant files
3. create or refresh `PLAN.md`
4. review plan to `READY` or `CHALLENGED`
5. implement small steps
6. run focused checks
7. archive the implemented plan in `docs/plan/`
8. review diff
9. commit once verified
