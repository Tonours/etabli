# Workflow contract details

Long-form rules and loop narrative for Etabli. The short map is
`workflow/spec.md`; the agent entry page is `workflow/agent-quick-card.md`.
Do not treat this file as a second routing table — the code and the map decide.

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

Ordinary work remains single-agent unless an active runtime profile admits a
sidecar. Pi uses the deterministic adaptive profile in
`workflow/skills/multi-model-orchestration.md`: no sidecar at score zero, one
route-appropriate scout for material uncertainty or failure history, and a
two-agent council for one critical or two distinct medium signals. System
complexity alone stays parent-only. Explicit opt-out forces the parent only.
Runtime-specific model portfolios and mechanics stay in their respective
profiles; shared workflow and evidence invariants stay in
`workflow/skills/orchestration.md`.

## Rules (detail)

- Read code directly before planning or editing.
- If shell startup or cwd resolution fails, retry from `/` with an explicit
  shell before declaring the tool or filesystem unavailable.
- For broad external research, repo-pattern, or fresh-context review, name the
  chosen slice first and prefer source claims, local contracts, memory, recent
  diffs, and existing docs before rereading the whole repository.
- When asked whether a source implies repository changes, answer `no change`,
  `change`, or `blocked` against the local contract before editing.
- Before mutable local-device or server actions, identify the exact target and
  control path, backup or rollback when relevant, and the post-check.
- Keep one execution artifact: `PLAN.md`.
- Archive implemented plans in `docs/plan/` only after implementation and validation.
- Do not create `REVIEW.md` or secondary mandatory planning docs.
- For small safe tasks, use the simple `PLAN_TEMPLATE.md` shape.
- For broad/risky work, use `PLAN_TEMPLATE_FULL.md`.
- Keep observed facts separate from assumptions in plans.
- Record exact validation commands and results before claiming completion.
- Source-backed research artifacts must include source evidence and confidence
  labels; validate them with `scripts/research-proof-check` when they are
  written to the repo.
- Answers and handoffs follow `workflow/answer-quality.md`: use the smallest
  evidence-backed response that satisfies the user's goal, labels uncertainty,
  and avoids unsupported claims.
- Durable answer, handoff, research, and obvault-backed artifacts can be checked
  with `scripts/answer-quality-check`; it is a quality floor, not a subjective
  10/10 scorer.
- Answer-quality helper behavior is pinned by
  `scripts/answer-quality-eval` and the versioned fixtures under
  `tests/fixtures/answer-quality/`.
- Saved answer and handoff reviews under `docs/answer-quality-traces/` are
  historical evidence, not another active validation layer.
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
- User-facing changes that materially affect product flows use the shared
  product dogfood contract in `workflow/skills/product-dogfood.md`: map flows
  before a scenario matrix, exercise observable UI/browser reality when
  available, and record `blocked` instead of claiming pass when decisive legs
  need human verification or no validation surface exists.
- Supervised single-PR maintenance loops use the shared pilot contract in
  `workflow/skills/pr-maintenance-loop.md`: one PR, one worktree, one loop,
  latest pushed head evidence via `scripts/pr-latest-head-status`,
  fresh-context review, explicit worktree cleanup, and no external
  write-back/deploy/push/merge unless another active command contract
  explicitly authorizes that action.
- Long or multi-packet runs may record durable progress as events in
  `.workflow/<slug>/events.jsonl` per `workflow/events.md`; resumption reads the
  ledger instead of chat history, and `completed` or `blocked` events are
  terminal evidence.
- `workflow-monitor`, `workflow-metrics`, `workflow-dossier`, and
  `workflow-retrospect` are experimental, on-demand, read-only ledger/archive
  readers. They support diagnostics and retrospective hypotheses; they are not
  part of the core gate. Telemetry does not establish user value until at least
  10 representative real tasks have task-grader outcomes.
- `workflow-telemetry-recover` is read-only by default and may append only a
  fingerprinted historical population plus aggregate imports to the active
  local ledger when explicitly invoked with `--apply`; it never rewrites target
  ledgers or persists conversation content, raw session IDs, or session paths.
  Recovered metrics count only while a read-only source recomputation exactly
  reproduces the stored import and current target fingerprints.
- Self-improvement work follows `workflow/skills/self-improvement-loop.md`:
  start from inspectable evidence, classify candidates, implement only through
  reviewed `PLAN.md`, and never auto-apply retrospective output.
- Ambitious project work follows `workflow/skills/ambitious-project-loop.md`:
  turn rough intent into spec/decisions/slices/execution/review/handoff without
  turning push, PR, deploy, release, or external write-back into implicit
  consent.
- As an experimental opt-in, an explicitly authorized bounded project may use
  `workflow/project-autonomy-envelope.md`: its controller is read-only, advances
  only declared verifiable slices from the ledger, and never replaces READY,
  checkpoint, no-progress, final-state-grader, or sealed-held-out gates.
- Autonomous routes (`plan-implement` autonome, `/goal`, `ci-fix`) must record
  the event ledger; ordinary work may record it.
- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`, emit a
  `no_progress` event, and list the eliminated hypotheses instead of iterating.
- Check-freeze: once `PLAN.md` is `READY`, its Checks and Acceptance Criteria
  may only be strengthened or extended during implementation. Weakening or
  removing one requires demoting the plan to `CHALLENGED` with a Decision Log
  rationale, never a silent edit. Mechanical helper and runtime guard:
  `scripts/plan-check-freeze` plus shared `planMutationGuardDecision` on PLAN.md
  tool writes (smoke: `tests/plan-check-freeze-smoke.sh`,
  `tests/dual-runtime-guard-matrix-smoke.sh`).
- Autonomous loop stop conditions pair the measurable goal with an explicit cap
  (iterations or wall-clock). `ci-fix` keeps its existing attempt and time caps.
- The final review of an autonomous `plan-implement` run comes from a fresh
  context (subagent reviewer or cross-model), never from the context that
  implemented. If no fresh-context runner is available, stop as `blocked`
  requesting external review instead of self-reviewing.
- The canonical adaptive profile or explicit authorization for read-only
  fresh-context review is reusable inside the active run: when the profile
  applies, or a user plainly authorizes subagents/delegation/reviewers, launch
  one read-only reviewer when a runner is available and record its id/verdict.
  This authorization is for read-only fresh-context review only; it
  does not authorize destructive, secret, production, billing, deploy, push,
  merge, or external write actions.
- Session handoffs in autonomous runs are recorded as a `handoff` event
  (branch, sha, done, pending, next action, do-not-redo), not as ad-hoc prose.
- Golden principles: a new transverse invariant ships with a mechanical check
  (hook, lint, or smoke assertion) in the same change, instead of prose
  duplicated across adapters. Instruction files stay maps, not manuals. The
  third occurrence of the same review finding becomes a mechanical check.
  Every mechanical check fails with a message that names its remediation.
  A routing or guard failure observed in real use becomes a fixture.
  Confirmed recurring findings from `workflow-retrospect` become reviewed
  recommendations, router fixtures, contract patches, or mechanical checks;
  the helper never applies patches or external write-back by itself.
- Skills, commands, and agent instructions follow `workflow/skill-design.md`.
- A code behavior change ships with tests written in the existing suite's
  conventions; a bug fix starts from a failing test that reproduces the
  issue. Docs and contract changes are validated by smoke pins or inspection
  instead.
- Reviewers flag only gaps that affect correctness or stated requirements;
  style preferences and speculative robustness are optional notes, never
  blockers.
- A started migration is finished or explicitly handed off with a `handoff`
  event; a half-migrated state is never left silent.

## Human checkpoints (detail)

Checkpoints sit at irreversibility boundaries, not every step. A checkpoint
consumed by explicit user invocation, such as `/linear-ticket-create`, is
consent for that command's external write contract. When a run ledger exists,
journal checkpoint decisions as `human_checkpoint` events in
`.workflow/<slug>/events.jsonl` per `workflow/events.md`. The routing decision
itself (destructive, secret, production, billing, external write-back →
`ops-stop`) lives in the Routing rules table in `workflow/spec.md`; this table
documents the enforcement behind each boundary.

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

## Runtime surfaces (detail)

Pi and Claude wrappers are thin runtime adapters over the shared contract.

- Pi skills: `pi/skills/`
- Claude commands: `claude/commands/`
- Shared skill contracts: `workflow/skills/`
- Self-improvement contract: `workflow/skills/self-improvement-loop.md`
- Ambitious project contract: `workflow/skills/ambitious-project-loop.md`
- Bounded project autonomy envelope: `workflow/project-autonomy-envelope.md`
- Bounded project autonomy controller: `scripts/project-autonomy`
- Product dogfood contract: `workflow/skills/product-dogfood.md`
- Single-PR maintenance contract: `workflow/skills/pr-maintenance-loop.md`
- Claude optional hooks: `claude/hooks/` with
  `claude/settings.workflow-hooks.json`
- Orchestration contract: `workflow/skills/orchestration.md`
- Answer quality contract: `workflow/answer-quality.md`
- Answer quality helper: `scripts/answer-quality-check`
- Answer quality eval: `scripts/answer-quality-eval`
- Latest-head PR evidence helper: `scripts/pr-latest-head-status`
- Runtime capability matrix: `workflow/runtime-capabilities.json`
- Explicit-use Pi named-workflow adapter: `workflow/pi-workflow-adapter.md`
- Plan templates: `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`
- Implemented plan archives: `docs/plan/` in workflow-scaffolded projects (`workflow/plan-archive.md`)
- Project context: `docs/project-context.md` in workflow-scaffolded projects
- Agent memory: `docs/agent-memory/` in workflow-scaffolded projects (`workflow/memory.md`)
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Linear ticket template: `workflow/linear-ticket-template.md`

## Default commands (detail)

Pi:

- `/workflow ...` is an explicit-use third-party Pi adapter, never an ambient Etabli
  route. Its first approved slice is the bundled read-only `spec-review` and
  `impact-review` workflows; see `workflow/pi-workflow-adapter.md` for state,
  delegation, and non-sandbox boundaries.
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
