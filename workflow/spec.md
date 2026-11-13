# Workflow Spec

Canonical workflow **map** for `etabli` and the single agent entry point.

## Flow

```text
learn -> plan -> implement -> review -> validate
```

## Activation

The workflow is ambient in any project containing `workflow/spec.md`: agents
infer the smallest matching route from the request and repo state, unprompted.

## Agentic workflow loop

Claude Code, Codex and Pi are thin adapters over shared contracts
(ADR-0006). Shared orchestration: `workflow/skills/orchestration.md`. Single writer and risk
tiers: `workflow/skills/implementation-loop.md`; `scout` and `reviewer` stay
read-only (Bash `PreToolUse` allowlist).

```text
user intent -> planner -> challenger -> adversary -> implementer -> verifier -> reviewer -> reporter -> stop
```

## Statuses

`PLAN.md` uses one status:

- `DRAFT`: plan exists, not implementation-ready.
- `CHALLENGED`: review found blockers or vague scope/checks.
- `READY`: the minimum contract below is present and scope,
  steps, checks, risks, and material spec/code gaps are clear enough to execute.

For routes with a plan, only `READY` authorizes implementation. Ordinary no-plan
work follows the Routing rules below; plan status and risk tier are not routes.

## Rules (map)

Non-negotiables:

- Read code before planning or editing; retry from `/` with an explicit shell if
  cwd fails.
- For broad external research, repo-pattern, or fresh-context review, name the
  slice first.
- When asked whether a source implies repository changes, answer `no change`,
  `change`, or `blocked` against the local contract before editing.
- Before mutable local-device or server actions, name target, control path,
  post-check and rollback.
- One execution artifact: `PLAN.md`. No `REVIEW.md` second plan.
- Keep facts separate from assumptions; use `PLAN_TEMPLATE.md` /
  `PLAN_TEMPLATE_FULL.md` as appropriate.
- Answers/handoffs: `workflow/answer-quality.md`.
- Autonomous plan-loop requests use `plan-implement`. Prompt wording such as "PLAN.md ready" is routing context, not proof.
- Implementation-bound autonomous loops are not complete until validation,
  adversary evidence, review, implemented-plan archive under `docs/plan/`, and
  root `PLAN.md` cleanup are evidenced.
- Work spanning several repos still uses one plan: one owner repo holds root
  `PLAN.md` and the single archive, other repos are declared satellites, and the
  archive is never duplicated. Stale and invalid-status plans are surfaced by
  `scripts/plan-cleanup --status`. Both rules: `workflow/plan-archive.md`.
- Branch-mutating runs isolate per
  `workflow/skills/worktree-isolation.md`: one run, one worktree, root `PLAN.md`
  inside it, explicit cleanup.
- Evidence and investigations: `workflow/skills/investigation.md`. Integrity,
  parent-observed execution, proxy support, and blocked surfaces stay distinct.
- Run evidence lives in `PLAN.md`: check results in Checks, review and adversary
  provenance (model, `shasum -a 256 PLAN.md` at dispatch, verdict) in Review
  Changes; current handoff in Notes / Handoff follows
  `workflow/skills/implementation-loop.md` § Standing rules.
- Pre-READY, edit only root `PLAN.md`. On resume, archive validated work or
  discard an unrelated plan with `scripts/plan-cleanup --discard <reason-slug>`;
  age alone is not abandonment (`workflow/plan-archive.md`).
- Validation: focused checks over full-suite ritual (`scripts/verify-agentic-infra core`,
  `bun test pi/extensions/__tests__/`); record commands and results.
- Review: Logic hunter then Spec hunter, plus the Threat hunter on access,
  trust-boundary or public-API changes; `GO` needs a filled deciding-code table
  for runtime diffs (`workflow/review-rubric.md`). An escaped defect after `GO`
  fills `workflow/templates/escaped-defect.md`.
- Cold contract, opened only on its trigger: bounded re-review
  `workflow/skills/review-rounds.md` (findings, re-review, CI commits after
  review).
- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`, note
  it in the Decision Log, and list the eliminated hypotheses.
- READY plans stay editable: when Checks or Acceptance Criteria change, note
  why in the Decision Log. No runtime freeze.
- Autonomous loop stop conditions pair the measurable goal with an explicit
  operational cap (iterations or wall-clock). Global model-token totals are
  telemetry, never plan/goal stop conditions. Bounded payload contracts and
  explicit billing authorization remain separate. The final review of an
  autonomous `plan-implement` run comes from a fresh
  context (subagent reviewer or cross-model). Handoffs are recorded in
  `PLAN.md` § Notes / Handoff.
- When no plan-route row matches, non-semantic editorial edits on any repo
  surface (wording, links, examples, comments, test failure messages) are small:
  `answer` route, self-review, core checks, no plan. The exclusions in
  `workflow/skills/implementation-loop.md` § Risk tiers apply; route, gate,
  obligation, assertion or runtime changes keep their tier. In-flight delta
  escalation (`workflow/skills/review-rounds.md`) is unchanged.
- Golden principles: every mechanical check fails with a message that names its remediation.
  Instruction files stay maps, not manuals.
  Recurring findings become reviewed recommendations, never auto-applied; no parallel harness trees.
  Skill design: `workflow/skill-design.md`. A code behavior change ships with tests in the suite's
  conventions; docs and contracts are validated by smoke pins or inspection. A bug fix starts from
  a failing test that reproduces the issue. The third occurrence of the same finding becomes a
  mechanical check in the project's own tooling. Reviewers flag only gaps that affect correctness
  or stated requirements.
  A started migration is finished or explicitly handed off in `PLAN.md` § Notes / Handoff.

## Minimal READY gate

A plan is `READY` when it has:

- clear goal
- bounded scope and non-goals when needed
- concrete steps
- named files/areas for risky changes
- checks to run
- route, role, stop condition, and required evidence
- known risks or explicit "none"
- facts separated from assumptions when the task depends on uncertain context
- populated requirement trace with a disposition for every material spec/code gap
- no blocking open questions
- no active raw HTML as semantic evidence; use Markdown text, inline code, fenced code,
  or explicit `command:` lines

## Routing rules

Rows are checked top to bottom; the first matching row wins.

| Trigger | Route | Artifact | Stop |
| --- | --- | --- | --- |
| Adversarial plan review without "do not edit" intent | `adversary` | updated `PLAN.md` | `READY`, `CHALLENGED`, or blocker |
| Review request (diff, GitHub PR, plan) or adversarial review with "do not edit" intent | `review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| Existing `READY PLAN.md` covering the requested task, plus implementation request | `implement` | code/docs + archive | validated archive and root `PLAN.md` deleted |
| "plan puis implémente", autonomous `plan-loop`, end-to-end ("A to Z") project, Linear ticket implementation, or self-improvement from run evidence | `plan-implement` | `PLAN.md` then code/docs | validated archive and root `PLAN.md` deleted, or explicit no-op/blocker |
| Broad task, unclear implementation, or explicit plan request ("fais un plan") | `plan-loop` | `PLAN.md` | `READY` or `CHALLENGED` |
| Question, explanation, diagnosis, compare, verify or retest a claim, or forensics | `answer` | none | answer delivered; no `PLAN.md` |
| Ordinary coding with no root `PLAN.md` (a bounded fix runs its tier's journey, below) | `answer` | code/docs | edit complete |

Work commands are explicit commands (work scope), never chosen from the
table: `/linear-ticket-create`, `/pr-council-review`. Each runs under its own contract. Linear
commands require Linear MCP or stop with `LINEAR_MCP_UNAVAILABLE` — see
`docs/mcp-strategy.md` § Linear MCP gap. Rationale: ADR-0027.

Obligations per case (tiers: `workflow/skills/implementation-loop.md`): planned
work runs its tier's full sequence; a bounded fix needs no plan but a failing
reproducer, focused checks and one fresh-context review; a review-only request
returns findings and stops; host-restricted effects follow § Human checkpoints.

A route says what to produce and when to stop; it does not say what the area
already taught us. Where the runtime exposes skills, select the narrowest domain
or project skill for the subject alongside the route — they are orthogonal, and
the skill keeps a route from rediscovering known ground. Optional domain skills
are **opt-in**: load one only when the runtime exposes it and the brief clearly
matches, never as a mandatory first step on `plan-loop` or `plan-implement`. A project skill wins over a generic language/framework skill when the
task is about the codebase. When no matching skill is exposed, the route still
follows its local-source fallback instead of silently skipping the phase.
Selection stays with the model, never injected per prompt (ADR-0014).

## Human checkpoints

None. Deletion, production, billing, history rewrite, pushes, and external
write-back run without a stop (ADR-0032); secrets are never printed or
committed. Under a host that gates effects, such as a fleet session
(`FLEET_SESSION_ID` set), the host's rules win: push only the run's branch,
open its PR, and ask the host for any other effect.

The model routes from the table above (ADR-0036); actual plan state and the
remaining write gates (no-comments, read-only agents) stay authoritative code.

## Runtime surfaces

Surfaces not mapped above: Claude hooks `claude/hooks/` with
`claude/settings.workflow-hooks.json`; Linear tickets
`workflow/linear-ticket-template.md`; scaffolded projects keep
`docs/project-context.md`, `docs/plan/` and `docs/agent-memory/`.
