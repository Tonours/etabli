# Workflow Spec

Canonical workflow **map** for `etabli`. Long rules and command lists live in
`workflow/contract-details.md`. Agent one-pager: `workflow/agent-quick-card.md`.

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

Pi remains the primary user-facing tool. Thin adapters over shared contracts
(ADR-0006). Role chain and multi-model policy: see `workflow/contract-details.md`
and the deterministic adaptive profile in
`workflow/skills/multi-model-orchestration.md`. Shared orchestration:
`workflow/skills/orchestration.md`.

```text
user intent -> router -> planner -> challenger -> adversary -> implementer -> verifier -> reviewer -> reporter -> stop
```

## Statuses

`PLAN.md` uses one status:

- `DRAFT`: plan exists, not implementation-ready.
- `CHALLENGED`: review found blockers or vague scope/checks.
- `READY`: scope, steps, checks, and risks are clear enough to execute.

Only `READY` authorizes implementation.

## Rules (map)

Full prose: `workflow/contract-details.md`. Non-negotiables:

- Read code before planning or editing; retry from `/` with an explicit shell if
  cwd fails.
- For broad external research, repo-pattern, or fresh-context review, name the
  slice first.
- When asked whether a source implies repository changes, answer `no change`,
  `change`, or `blocked` against the local contract before editing.
- Before mutable local-device or server actions, name target, control path, and
  post-check.
- One execution artifact: `PLAN.md`. No `REVIEW.md` second plan.
- Keep facts separate from assumptions; use `PLAN_TEMPLATE.md` /
  `PLAN_TEMPLATE_FULL.md` as appropriate.
- Source research: `scripts/research-proof-check`. Answers/handoffs:
  `workflow/answer-quality.md`; durable floor:
  `scripts/answer-quality-check` / `scripts/answer-quality-eval`.
- Autonomous plan-loop requests use `plan-implement`. Prompt wording such as "PLAN.md ready" is routing context, not proof.
- Implementation-bound autonomous loops are not complete until validation,
  adversary evidence, review, implemented-plan archive under `docs/plan/`, and
  root `PLAN.md` cleanup are evidenced.
- Product dogfood: `workflow/skills/product-dogfood.md`. Single-PR pilot:
  `workflow/skills/pr-maintenance-loop.md` — one PR, one worktree, one loop;
  `scripts/pr-latest-head-status`; no external write-back/deploy/push/merge
  without another explicit command contract.
- Events: `workflow/events.md`. Autonomous routes (`plan-implement` autonome, `/goal`, `ci-fix`) must record
  the event ledger; ordinary work may record it.
- Experimental read-only: `workflow-monitor`, `workflow-metrics`,
  `workflow-dossier`, `workflow-retrospect` (not core gate; ≥10 task-grader
  outcomes before claiming telemetry value).
- Self-improvement: `workflow/skills/self-improvement-loop.md`. Ambitious
  projects: `workflow/skills/ambitious-project-loop.md`. Opt-in autonomy:
  `workflow/project-autonomy-envelope.md`.
- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`.
- Check-freeze: once READY, Checks/Acceptance Criteria strengthen-only;
  demoting the plan to `CHALLENGED` with a Decision Log rationale required to
  weaken. Runtime: shared `planMutationGuardDecision` on PLAN.md writes
  (Pi `tool_call` + Claude `plan-ready-guard`); CLI `scripts/plan-check-freeze`.
- Autonomous loop stop conditions pair the measurable goal with an explicit cap
  (iterations or wall-clock). The final review of an autonomous `plan-implement`
  run comes from a fresh
  context (subagent reviewer or cross-model). This authorization is for
  read-only fresh-context review only; it
  does not authorize destructive, secret, production, billing, deploy, push,
  merge, or external write actions. Handoffs are recorded as a `handoff` event.
- Golden principles: every mechanical check fails with a message that names its remediation.
  Instruction files stay maps, not manuals. The
  third occurrence of the same review finding becomes a mechanical check.
  Confirmed recurring findings from `workflow-retrospect` become reviewed
  recommendations, never auto-applied.
  Skill design: `workflow/skill-design.md`. A bug fix starts from a failing test that reproduces
  the issue. Reviewers flag only gaps that affect correctness or stated requirements.
  A started migration is finished or explicitly handed off with a `handoff` event.

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
| Self-improvement request from run evidence, retrospect output, recurring findings, or workflow failures | `plan-implement` | `PLAN.md` + workflow contract/router/check changes | validated archive and root `PLAN.md` deleted, or explicit no-op/blocker |
| Ambitious project, "A to Z", "de a a z", or end-to-end project request without explicit `/ship` | `plan-implement` | `PLAN.md` + spec/slices/workflow artifacts/code/docs as needed | validated archive and handoff; no push/PR/deploy without explicit command contract |
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

`spec-guide` is ambient. Linear routes require Linear MCP or stop with
`LINEAR_MCP_UNAVAILABLE` — see `docs/mcp-strategy.md`.

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
| read-only fresh-context review | subagent/cross-model reviewer for implementation diff | canonical adaptive profile or explicit user authorization, plus available runner | launch one read-only reviewer, record `human_checkpoint` and reviewer evidence |
| premature implementation | writes while root `PLAN.md` is `DRAFT`/`CHALLENGED` (missing PLAN exempt for ordinary work) | shared `planMutationGuardDecision` (Claude `plan-ready-guard` + Pi `tool_call`) | tool call denied |
| check-freeze weaken | remove/weaken READY Checks without demote | same shared guard on PLAN.md writes | tool call denied |
| no_progress ledger stop | active non-terminal `.workflow/*/events.jsonl` with explicit `no_progress` or derived 2/3 thresholds | shared `planMutationGuardDecision` + `scripts/lib/no-progress-guard.mjs` | ordinary code mutations denied; PLAN.md + `scripts/workflow-event` escape allowed |
| ledger auto-emit | bash failure while active non-terminal ledger exists | Pi `tool_result` + Claude PostToolUse `ledger-auto-emit.mjs` | append `validation_failed`; may append `no_progress`; no emit without ledger |
| ambiguous target | "clean up the repo" with several plausible repos or paths | prose rule: name target; confirm when ≥2 plausible | ask, do not guess |
| missing validation surface | change with no runnable check | stop as `blocked: no validation surface` | report blocked |

Adapter coverage: routes shared by Pi extension and Claude hooks except
`tasks-till-done` (Pi-only). Executable classifier:
`claude/hooks/workflow-router-lib.mjs` via `workflow/runtime/workflow-router-core.mjs`.

## Runtime surfaces (index)

- Shared skill contracts: `workflow/skills/`
- Orchestration contract: `workflow/skills/orchestration.md`
- Answer quality contract: `workflow/answer-quality.md`
- Single-PR maintenance contract: `workflow/skills/pr-maintenance-loop.md`
- Latest-head PR evidence helper: `scripts/pr-latest-head-status`
- Runtime capability matrix: `workflow/runtime-capabilities.json`
- Explicit-use Pi named-workflow adapter: `workflow/pi-workflow-adapter.md`
- Implemented plan archives: `docs/plan/` (`workflow/plan-archive.md`)
- Agent memory: `docs/agent-memory/` (`workflow/memory.md`)
- Claude hooks fragment: `claude/settings.workflow-hooks.json`
- Pi `/workflow`: `workflow/pi-workflow-adapter.md`
- Project autonomy: `workflow/project-autonomy-envelope.md`
- Claude `/verify-workflow`; Pi `/skill:verify`
- Commands detail (Pi/Claude lists, `/goal <measurable condition>`):
  `workflow/contract-details.md`

## Daily loop

See `workflow/contract-details.md` § Daily loop (inspect → plan → READY →
adversary → implement → checks → review → archive → delete root PLAN.md).
