# Workflow Spec

Canonical workflow contract for `etabli`.

## Flow

```text
learn -> plan -> implement -> review -> validate
```

## Activation

The workflow is ambient in any project that contains `workflow/spec.md`. Users
should not need to write "use the Etabli workflow" in normal prompts. Agents
must infer the smallest matching route from the request and local repo state.
Explicit markers such as `/goal`, `plan-loop`, `workflow`, `subagents`,
`jusqu'au bout`, `review`, or `verify` select specialized routes; they are not
required for ordinary bug fixes, feature work, reviews, or verification.

## Agentic workflow loop

Pi remains the primary user-facing tool. The deterministic layer is a small set
of role contracts, templates, skills, extensions, checks, and stop conditions
composed inside Pi. Keep harness-specific mechanics in thin adapters; keep the
shared behavior in tracked workflow sources.

Use the smallest workflow that can finish with evidence:

```text
user intent -> router -> planner -> challenger -> adversary -> implementer -> verifier -> reviewer -> reporter -> stop
```

Roles are contracts, not mandatory separate agents:

- `router`: classify the request into the smallest valid workflow.
- `planner`: create or refresh `PLAN.md` and stop at `READY` or `CHALLENGED`.
- `challenger`: reject vague scope, missing checks, hidden assumptions, and weak
  stop conditions before implementation.
- `adversary`: stress-test `PLAN.md` before implementation, fold accepted
  findings into the active plan, and keep `READY` only when no blocker remains.
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
- Implementation-bound plans run an adversary pass before implementation.
- Implementation follows plan steps in order.
- Implementation commands archive the final implemented plan as a distilled memory record, not a raw `PLAN.md` copy.
- Autonomous plan-loop requests use `plan-implement`: first run the `plan-loop`
  behavior, then continue to implementation only after the actual root
  `PLAN.md` is `READY`.
- Prompt wording such as "PLAN.md ready" is routing context, not proof; the
  implementation gate is the status recorded in the actual root `PLAN.md`.
- Implementation-bound autonomous loops are not complete until validation,
  adversary evidence, review, implemented-plan archive under `docs/plan/`, and
  root `PLAN.md` cleanup are evidenced.
- If new facts invalidate the plan, update it before continuing.
- If new facts materially invalidate the implementation route or checks, stop as
  plan drift instead of silently continuing.
- Review checks correctness, regressions, safety, validation, and plan drift.
- Prefer focused checks over full-suite ritual.
- Long or multi-packet runs may record durable progress as events in
  `.workflow/<slug>/events.jsonl` per `workflow/events.md`; resumption reads the
  ledger instead of chat history, and `completed` or `blocked` events are
  terminal evidence.
- Autonomous routes (`plan-implement` autonome, `/goal`, `ci-fix`) must record
  the event ledger; ordinary work may record it.
- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`, emit a
  `no_progress` event, and list the eliminated hypotheses instead of iterating.
- Check-freeze: once `PLAN.md` is `READY`, its Checks and Acceptance Criteria
  may only be strengthened or extended during implementation. Weakening or
  removing one requires demoting the plan to `CHALLENGED` with a Decision Log
  rationale, never a silent edit.
- Autonomous loop stop conditions pair the measurable goal with an explicit cap
  (iterations or wall-clock). `ci-fix` keeps its existing attempt and time caps.
- The final review of an autonomous `plan-implement` run comes from a fresh
  context (subagent reviewer or cross-model), never from the context that
  implemented. If no fresh-context runner is available, stop as `blocked`
  requesting external review instead of self-reviewing.
- Session handoffs in autonomous runs are recorded as a `handoff` event
  (branch, sha, done, pending, next action, do-not-redo), not as ad-hoc prose.
- Golden principles: a new transverse invariant ships with a mechanical check
  (hook, lint, or smoke assertion) in the same change, instead of prose
  duplicated across adapters. Instruction files stay maps, not manuals.

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
| Guided spec construction ("rédige une spec", "guide-moi pour la spec") | `spec-guide` | spec drafted via `/spec` template | spec solid, hands off to `/spec` |
| Read-only adversarial PLAN.md review, or adversarial review with "do not edit" intent | `review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| Adversarial plan review | `adversary` | updated `PLAN.md` | `READY`, `CHALLENGED`, or blocker |
| Existing `READY PLAN.md` plus implementation request | `implement` | code/docs + archive | validated archive and root `PLAN.md` deleted |
| "plan puis implémente", autonomous `plan-loop`, or equivalent | `plan-implement` | `PLAN.md` then code/docs | validated archive and root `PLAN.md` deleted |
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

## Human checkpoints

Checkpoints sit at irreversibility boundaries, not every step. A checkpoint
consumed by explicit user invocation, such as `/linear-ticket-create`, is
consent for that command's external write contract. When a run ledger exists,
journal checkpoint decisions as `human_checkpoint` events in
`.workflow/<slug>/events.jsonl` per `workflow/events.md`.

| Category | Examples | Enforcement | Behavior |
| --- | --- | --- | --- |
| deletion / destructive | `rm -rf`, drop/truncate, delete repo or branch | router `OPS_STOP_PATTERN` in both adapters | route `ops-stop`, risk brief, wait |
| production / billing write | deploy, prod config, billing | router `OPS_STOP_PATTERN` | route `ops-stop` |
| history rewrite / push | force-push, `git push`, rebase published history | router `OPS_STOP_PATTERN`; explicit `/ci-fix` is the consented exception checked first | route `ops-stop` unless explicit `ci-fix` |
| secrets / credentials | reading, writing, or printing secrets | router `OPS_STOP_PATTERN`, Pi `filter-output`, and sensitive-file blocks | route `ops-stop`; output redaction |
| external write-back | post PR review/comment, update Linear status, publish | command-level HITL contracts (`/pr-review`, `/sec-pr`, `/linear-*`) plus router `EXTERNAL_WRITE_BACK_PATTERN` for bare prompts | command contract or `ops-stop` |
| premature implementation | any write before root `PLAN.md` is `READY` | `plan-ready-guard` hook for Claude; READY gate rule for all adapters | tool call denied |
| ambiguous target | "clean up the repo" with several plausible repos or paths | prose rule: the agent must name the resolved target and get confirmation when >=2 targets are plausible | ask, do not guess |
| missing validation surface | change with no runnable check or inspectable proof | prose rule: stop as `blocked: no validation surface` instead of claiming completion | report blocked |

Adapter coverage: all routes are shared by the Pi extension router and the
Claude hook router, except `tasks-till-done` (Pi-only Task* runtime). The
executable source of truth for classification is
`claude/hooks/workflow-router-lib.mjs` and
`pi/extensions/lib/workflow-router-runtime.ts`; this table documents intent,
the code decides.

## Runtime surfaces

Pi and Claude wrappers are thin runtime adapters over this contract.

- Pi skills: `pi/skills/`
- Claude commands: `claude/commands/`
- Shared skill contracts: `workflow/skills/`
- Claude optional hooks: `claude/hooks/` with
  `claude/settings.workflow-hooks.json`
- Orchestration contract: `workflow/skills/orchestration.md`
- Runtime capability matrix: `workflow/runtime-capabilities.json`
- Plan templates: `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`
- Implemented plan archives: `docs/plan/` in workflow-scaffolded projects (`workflow/plan-archive.md`)
- Project context: `docs/project-context.md` in workflow-scaffolded projects
- Agent memory: `docs/agent-memory/` in workflow-scaffolded projects (`workflow/memory.md`)
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Linear ticket template: `workflow/linear-ticket-template.md`

Runtime adapters should point to shared contracts instead of duplicating phase
order. Add a shared contract only when two harnesses must preserve the same
behavior.

## Default commands

Pi:

- `/skill:plan-loop <task>`: create/review `PLAN.md`, stop at `READY` or `CHALLENGED`
- `/skill:plan-implement <task>`: plan, then implement if `READY`
- `/skill:adversary`: adversarially review `PLAN.md` before implementation
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
- `/plan-implement`: full autonomous chain — plan, adversary, implement, checks, fresh-context review, archive — in one flow; the manual `/plan-loop` -> `/adversary` -> `/implement` sequence is for step-by-step control only
- `/adversary`: cross-model adversarial review of `PLAN.md` before implementation
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

Manual-only Claude commands (invoked by explicit slash only, never ambiently
routed): `/ship` (A-to-Z delivery per `workflow/skills/ship.md`; invoking it
consents to feature-branch push and PR creation), `/spec-verify`, `/commit`,
`/cross-repo-audit`,
`/linear-project-setup`, `/pr-feedback`, `/pre-commit`, `/tests-iso`,
`/front-quality`, `/ui-debug`, `/recap`. The Playwright QA chain lives in the
`claude/skills/playwright-*` skills and `claude/agents/playwright-*`
subagents, not in slash commands.
`/spec-guide` is routed ambiently (see routing table). `/plan` maps to
`claude/commands/plan-create.md`.

Claude-native loop:

- Use `/goal <measurable condition>` for long-running completion loops instead
  of recreating Pi's Task* continuation layer. The goal statement must pair the
  measurable condition with an explicit cap (iterations or wall-clock), and the
  run must record the event ledger per `workflow/events.md`.
- Use `claude/settings.workflow-hooks.json` as an opt-in settings fragment for
  routing context and READY-gate hook enforcement.
- Claude orchestration parity labels: see `workflow/runtime-capabilities.json`.
  Do not claim Claude has Pi Task* semantics.

## Daily loop

1. inspect repo state
2. read relevant files
3. create or refresh `PLAN.md`
4. review plan to `READY` or `CHALLENGED`
5. run adversary against implementation-bound `PLAN.md`; fold accepted findings
   and keep `READY` only if no blocker remains
6. if the selected route is `plan-implement` and the actual root `PLAN.md` is
   `READY`, continue without asking for another prompt
7. implement small steps
8. run focused checks
9. review diff against the plan
10. archive the implemented plan in `docs/plan/`
11. delete only the root `PLAN.md` after archive and validation
12. commit once verified when the user asked for a commit
