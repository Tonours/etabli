# Workflow contract details

Long-form rules and loop narrative for Etabli. The entry and short map is
`workflow/spec.md`.
Do not treat this file as a second routing table — the code and the map decide.

## Agentic workflow loop

Pi remains the primary user-facing tool. The deterministic layer is a small set
of role contracts, templates, skills, extensions, checks, and stop conditions
composed inside Pi; harness-specific mechanics live in thin adapters, shared
behavior in tracked workflow sources.

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
- `implementer`: on a plan route, execute only a `READY` plan, in order, with minimal drift.
- `verifier`: prove or reject completion from checks, artifacts, sources, or
  command output without editing.
- `reviewer`: inspect diff correctness, regressions, safety, validation, and
  plan drift without editing.
- `reporter`: leave durable state through final handoff and implemented plan
  archives when applicable.

One writer at any instant. The parent writes, or delegates writing to at most
one `worker` at a time — foreground, or the parent waits without writing until
it finishes, then takes the pen back between plan steps; never two writers in
parallel.

The deterministic multi-model council (scout / analyst / challenger /
judge / fallback) was removed in ADR-0013; `classifyWorkflowRoute` always
attaches parent-only `multiExecution`. Delegating to a subagent stays an
ordinary tool call, judged case by case, not a routed profile. `scout` and
`reviewer` combine an explicit read-only tool set, `dontAsk`, and a scoped Bash
`PreToolUse` allowlist guard; this is stronger than prose but still not an OS
sandbox. Shared workflow and evidence invariants stay in
`workflow/skills/orchestration.md`.

## Rules (detail)

- Read code directly before planning or editing.
- If shell startup or cwd resolution fails, retry from `/` with an explicit
  shell before declaring the tool or filesystem unavailable.
- Scope broad research/review; prefer memory, contracts, recent diffs.
  Search symbols/ranges; reuse stable ticket/docs results, refresh on relevant
  change. Keep evidence, errors and exit codes.
- When asked whether a source implies repository changes, answer `no change`,
  `change`, or `blocked` against the local contract before editing.
- Before local-device/server mutations, identify target, control path,
  backup/rollback and post-check.
- Keep one execution artifact: `PLAN.md`.
- Archive implemented plans in `docs/plan/` only after implementation and validation.
- Do not create `REVIEW.md` or secondary mandatory planning docs.
- Use the simple `PLAN_TEMPLATE.md` shape for small safe tasks and
  `PLAN_TEMPLATE_FULL.md` for broad/risky work.
- Keep observed facts separate from assumptions in plans.
- Record exact validation commands and results before claiming completion.
- Source-backed research artifacts must include source evidence and confidence
  labels.
- Answers and handoffs follow `workflow/answer-quality.md`: use the smallest
  evidence-backed response that satisfies the user's goal, labels uncertainty,
  and avoids unsupported claims.
- Record route, role, stop condition, and required evidence in every plan (the gate requires them unconditionally).
- Planning review updates `PLAN.md` in place.
- Implementation-bound plans run an adversary pass before implementation.
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
- Prefer focused checks over full-suite ritual.
- User-facing changes that materially affect product flows exercise observable
  UI/browser reality when available, and record `blocked` instead of claiming
  pass when decisive legs need human verification or no validation surface
  exists.
- Runs that mutate code on a dedicated branch isolate through `workflow/skills/worktree-isolation.md`: clean base
  worktree, one run per worktree and branch, no sibling-worktree edits, the run's
  root `PLAN.md` inside its own worktree, environment contention reported as
  `blocked`, and explicit cleanup or a stated reason for keeping it.
- Long or multi-packet runs record durable progress in `PLAN.md` (Checks
  `last run`, Decision Log, Notes / Handoff); resumption reads it.
- Workflow improvements start from inspectable evidence and go through a
  reviewed `PLAN.md`.
- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`, note it in the
  Decision Log, and list the eliminated hypotheses instead of iterating.
- READY plans stay editable during implementation: when Checks or Acceptance
  Criteria change, note why in the Decision Log. No runtime freeze.
- Autonomous loop stop conditions pair the measurable goal with an explicit cap
  (iterations or wall-clock).
- The final review of an autonomous `plan-implement` run comes from a fresh
  context (subagent reviewer or cross-model), never from the context that
  implemented. If no fresh-context runner is available, stop as `blocked`
  requesting external review instead of self-reviewing.
- Explicit user authorization for subagents, delegation, or reviewers may
  launch one read-only reviewer when a runner is available; record its
  id/verdict. Autonomous `plan-implement` already requires this pass.
- Independent work starts a new session; continuing work resumes `PLAN.md`.
  Before switching, record the handoff (branch, sha, done, pending, next action,
  do-not-redo) in § Notes / Handoff; inspect it before switching. No automatic
  reset. Finish or hand off a migration.
- Golden principles: a new transverse invariant ships with a mechanical check
  (hook, lint, or smoke assertion) in the same change, instead of prose
  duplicated across adapters. Instruction files stay maps, not manuals. The
  third occurrence of the same review finding becomes a mechanical check
  (`workflow/project-constraints.md`). Every mechanical check fails with a message
  that names its remediation. A routing or guard failure observed in real use becomes a fixture.
- Skills, commands, and agent instructions follow `workflow/skill-design.md`.
- A code behavior change ships with tests written in the existing suite's
  conventions; a bug fix starts from a failing test that reproduces the
  issue. Docs and contract changes are validated by smoke pins or inspection
  instead.
- Reviewers flag only gaps that affect correctness or stated requirements;
  style preferences and speculative robustness are optional notes, never
  blockers.

## Human checkpoints (detail)

No approval checkpoints (ADR-0032): deletion, production and billing writes,
history rewrite, pushes, and external write-back (PR comments, Linear tickets,
publishing) run directly. User decisions that do happen go in the plan's
Decision Log.

| Category | Examples | Enforcement | Behavior |
| --- | --- | --- | --- |
| secrets / credentials | printing or committing secrets | sensitive-file blocks | never print or commit |
| read-only fresh-context review | subagent/cross-model reviewer for implementation diff | autonomous `plan-implement` or explicit user authorization, plus available runner | launch one read-only reviewer, record reviewer evidence |
| ambiguous target | "clean up the repo" with several plausible repos or paths | prose rule: name target; confirm when ≥2 plausible | ask, do not guess |
| missing validation surface | change with no runnable check | stop as `blocked: no validation surface` | report blocked |

## Runtime surfaces (detail)

Pi and Claude wrappers are thin runtime adapters over the shared contract.

- Pi skills: `pi/skills/`
- Claude commands: `claude/scopes/<scope>/commands/`
- Shared skill contracts: `workflow/skills/`
- Investigation/evidence contract: `workflow/skills/investigation.md`
- Claude optional hooks: `claude/hooks/` with
  `claude/settings.workflow-hooks.json`
- Guard journal: `workflow/runtime/guard-journal.mjs` — wired guard denials append
  `{ts, host, harness, guard, pattern, target, tool}` lines to `.workflow/guard-journal/`
  (best-effort, never blocks the deny) <!-- etabli-only -->
- Orchestration contract: `workflow/skills/orchestration.md`
- Answer quality: `workflow/answer-quality.md`
- Runtime capability matrix: `workflow/runtime-capabilities.json`
- Plan templates: `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`
- Implemented plan archives: `docs/plan/` in workflow-scaffolded projects (`workflow/plan-archive.md`)
- Project context: `docs/project-context.md` in workflow-scaffolded projects
- Agent memory: `docs/agent-memory/` in workflow-scaffolded projects (`workflow/memory.md`)
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Linear ticket template: `workflow/linear-ticket-template.md`
- PR body contract: `workflow/pr-body-contract.md`

## Default commands (detail)

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

Claude:

- `/plan-loop`: create/review `PLAN.md`, stop at `READY` or `CHALLENGED`
- `/plan-implement`: full autonomous chain — plan, adversary, implement, checks, fresh-context review, archive — in one flow; the manual `/plan-loop` -> `/adversary` -> `/implement` sequence is for step-by-step control only
- `/adversary`: review `PLAN.md` before implementation; code-diff mode follows the shared risk-tiered independence rules
- `/implement`: implement existing `READY` plan
- `/review`: review current diff
- `/verify-workflow`: verify checks, claims, or current work without editing
- `/bug-check`: analyze Linear bug root cause without editing
- `/linear-ticket-create`: create Linear tickets through Linear MCP
- `/linear-work`: work from Linear tickets through Linear MCP
- `/pr-council-review`: three-pass review of one GitHub PR, dry-run by default

Work commands (`/linear-*`, `/bug-check`, `/pr-council-review`) are explicit commands in the work scope, never routed
(ADR-0027).

Claude-native loop:

- Use `/goal <measurable condition>` for long-running completion loops instead
  of recreating Pi's Task* continuation layer. The goal statement must pair the
  measurable condition with an explicit cap (iterations or wall-clock), and the
  run records its evidence in `PLAN.md`.
- `claude/settings.workflow-hooks.json` wires the no-comments and rtk guards.
  Route classification stays
  library-only and injects no prompt context (ADR-0014).
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
