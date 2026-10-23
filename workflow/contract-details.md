# Workflow contract details

Long-form rules and loop narrative for Etabli. The entry and short map is
`workflow/spec.md`.
Do not treat this file as a second routing table — the map decides.

## Agentic workflow loop

Pi remains the primary user-facing tool. The deterministic layer is a small set
of role contracts, templates, skills, extensions, checks, and stop conditions
composed inside Pi; harness-specific mechanics live in thin adapters, shared
behavior in tracked workflow sources.

Use the smallest workflow that can finish with evidence; the role chain is in
`workflow/spec.md`. Roles are contracts, not mandatory separate agents:

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

Single writer: `workflow/skills/implementation-loop.md` step 8. Delegating to a
subagent stays an ordinary tool call, judged case by case, not a routed profile. `scout` and
`reviewer` rely on an explicit read-only tool set and a scoped Bash
`PreToolUse` allowlist guard in their frontmatter, which also fires under
bypass; their `dontAsk` applies only outside bypass, since a bypass session
overrides a subagent's `permissionMode`. This is stronger than prose but still
not an OS sandbox. Shared workflow and evidence invariants stay in
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
  becomes a mechanical check (`workflow/project-constraints.md`).
- A code behavior change ships with tests written in the existing suite's
  conventions. Docs and contract changes are validated by smoke pins or
  inspection instead. Style preferences and speculative robustness are optional
  review notes, never blockers.

## Runtime surfaces (detail)

Pi and Claude load the same thin skill adapters over the shared contract.

- Skill adapters (Claude and Pi): `skills/<scope>/<name>/SKILL.md`, catalogued
  in `workflow/runtime/skill-surface.tsv`
- Shared skill contracts: `workflow/skills/`
- Investigation/evidence contract: `workflow/skills/investigation.md`
- Claude optional hooks: `claude/hooks/` with
  `claude/settings.workflow-hooks.json`
- Orchestration contract: `workflow/skills/orchestration.md`
- Answer quality: `workflow/answer-quality.md`
- Plan templates: `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`
- Implemented plan archives: `docs/plan/` in workflow-scaffolded projects (`workflow/plan-archive.md`)
- Project context: `docs/project-context.md` in workflow-scaffolded projects
- Agent memory: `docs/agent-memory/` in workflow-scaffolded projects (`workflow/memory.md`)
- Review rubric: `workflow/review-rubric.md`
- Ticket template: `workflow/ticket-template.md`
- Linear ticket template: `workflow/linear-ticket-template.md`
- PR body contract: `workflow/pr-body-contract.md`
