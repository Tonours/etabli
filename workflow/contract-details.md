# Workflow contract details

Long-form rules and loop narrative for Etabli. The entry and short map is
`workflow/spec.md`.
Do not treat this file as a second routing table — the code and the map decide.

## Agentic workflow loop

Pi remains the primary user-facing tool. The deterministic layer is a small set
of role contracts, templates, skills, extensions, checks, and stop conditions
composed inside Pi; harness-specific mechanics live in thin adapters, shared
behavior in tracked workflow sources.

Use the smallest workflow that can finish with evidence; the role chain is in
`workflow/spec.md`. Roles are contracts, not mandatory separate agents:

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

Rules already stated in `workflow/spec.md` § Rules (map) are not repeated here;
this section only adds detail.

- Scope broad research/review; prefer memory, contracts, recent diffs.
  Search symbols/ranges; reuse stable ticket/docs results, refresh on relevant
  change. Keep evidence, errors and exit codes.
- Before local-device/server mutations, also name backup/rollback.
- Archive implemented plans in `docs/plan/` only after implementation and
  validation, as a distilled memory record, not a raw `PLAN.md` copy.
- Do not create secondary mandatory planning docs.
- Record exact validation commands and results before claiming completion.
- Source-backed research artifacts must include source evidence and confidence
  labels.
- Planning review updates `PLAN.md` in place. Implementation-bound plans run an
  adversary pass before implementation; `plan-implement` continues to
  implementation only after the actual root `PLAN.md` is `READY`.
- If new facts invalidate the plan, update it before continuing. If they
  materially invalidate the implementation route or checks, stop as plan drift
  instead of silently continuing.
- User-facing changes that materially affect product flows exercise observable
  UI/browser reality when available, and record `blocked` instead of claiming
  pass when decisive legs need human verification or no validation surface
  exists.
- Worktree isolation also means a clean base worktree, no sibling-worktree
  edits, and environment contention reported as `blocked`.
- Workflow improvements start from inspectable evidence and go through a
  reviewed `PLAN.md`.
- No-progress stop: also note it in the Decision Log and list the eliminated
  hypotheses instead of iterating.
- If no fresh-context runner is available for the final autonomous review, stop
  as `blocked` requesting external review instead of self-reviewing.
- Explicit user authorization for subagents, delegation, or reviewers may
  launch one read-only reviewer when a runner is available; record its
  id/verdict.
- Independent work starts a new session; continuing work resumes `PLAN.md`.
  Inspect the handoff before switching. No automatic reset.
- Golden principles, detail: a new transverse invariant ships with a mechanical
  check (hook, lint, or smoke assertion) in the same change, instead of prose
  duplicated across adapters. The third occurrence of the same review finding
  becomes a mechanical check (`workflow/project-constraints.md`). A routing or
  guard failure observed in real use becomes a fixture.
- A code behavior change ships with tests written in the existing suite's
  conventions. Docs and contract changes are validated by smoke pins or
  inspection instead. Style preferences and speculative robustness are optional
  review notes, never blockers.

## Human checkpoints (detail)

User decisions that do happen go in the plan's Decision Log.

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
