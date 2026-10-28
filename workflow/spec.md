# Workflow Spec

Canonical workflow **map** for `etabli` and the single agent entry point. Long
rules and command lists live in `workflow/contract-details.md`.

## Flow

```text
learn -> plan -> implement -> review -> validate
```

## Activation

The workflow is ambient in any project that contains `workflow/spec.md`. Users
should not need to write "use the Etabli workflow" in normal prompts. Agents
must infer the smallest matching route from the request and local repo state.

## Agentic workflow loop

Pi remains the primary user-facing tool. Thin adapters over shared contracts
(ADR-0006). Role definitions: `workflow/contract-details.md`. Shared
orchestration: `workflow/skills/orchestration.md`. Single writer and risk
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
- Evidence and investigations: `workflow/skills/investigation.md` and
  `workflow/evidence-pack.schema.json`. Integrity, parent-observed execution,
  proxy support, and blocked surfaces stay distinct.
- Run evidence lives in `PLAN.md`: check results in Checks, review and adversary
  provenance (model, `shasum -a 256 PLAN.md` at dispatch, verdict) in Review
  Changes, handoff (branch, sha, done, pending, next action, do-not-redo) in
  Notes / Handoff.
- Pre-READY, edit only root `PLAN.md`. On resume, archive validated work or
  discard an unrelated plan with `scripts/plan-cleanup --discard <reason-slug>`;
  age alone is not abandonment (`workflow/plan-archive.md`).
- Validation: focused checks over full-suite ritual (`scripts/verify-agentic-infra core`,
  `bun test pi/extensions/__tests__/`); record commands and results.
- Review: Logic hunter then Spec hunter, plus the Threat hunter on access,
  trust-boundary or public-API changes; `GO` needs a filled deciding-code table
  for runtime diffs (`workflow/review-rubric.md`). An escaped defect after `GO`
  fills `workflow/templates/escaped-defect.md`.
- Cold contracts, opened only on their trigger: bounded re-review
  `workflow/skills/review-rounds.md` (findings, re-review, CI commits after
  review); open-ended improvement loops `workflow/skills/long-loop.md`.
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
- Golden principles: every mechanical check fails with a message that names its remediation.
  Instruction files stay maps, not manuals.
  Recurring findings become reviewed recommendations, never auto-applied; no parallel harness trees.
  Skill design: `workflow/skill-design.md`. A bug fix starts from a failing test that reproduces
  the issue. Reviewers flag only gaps that affect correctness or stated requirements.
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
| Verify, retest, prove, or completion audit (interface `verify`; internal id `verify-workflow`) | `verify` | verification report | `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE` |
| Existing `READY PLAN.md` covering the requested task, plus implementation request | `implement` | code/docs + archive | validated archive and root `PLAN.md` deleted |
| "plan puis implémente", autonomous `plan-loop`, end-to-end ("A to Z") project, Linear ticket implementation, or self-improvement from run evidence | `plan-implement` | `PLAN.md` then code/docs | validated archive and root `PLAN.md` deleted, or explicit no-op/blocker |
| Broad task, unclear implementation, or explicit plan request ("fais un plan") | `plan-loop` | `PLAN.md` | `READY` or `CHALLENGED` |
| Question, explanation, diagnosis, compare, or forensics | `answer` | none | answer delivered; no `PLAN.md` |
| Ordinary coding with no root `PLAN.md` | `answer` | code/docs | edit complete |

Work commands are explicit commands (work scope), never chosen from the
table: `/linear-work`, `/linear-ticket-create`, `/linear-project-setup`,
`/bug-check`, `/pr-council-review`. Each runs under its own contract. Linear
commands require Linear MCP or stop with `LINEAR_MCP_UNAVAILABLE` — see
`docs/mcp-strategy.md` § Linear MCP gap. Rationale: ADR-0027.

`verify` is the contract route; its skill is `verify-workflow` on both runtimes
(`/verify-workflow`, `/skill:verify-workflow`), so Claude's native `/verify`
stays free.

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

Full index: `workflow/contract-details.md` § Runtime surfaces (detail). Key surfaces referenced by routing/guards: Claude hooks fragment
`claude/settings.workflow-hooks.json` and `workflow/plan-archive.md`.
