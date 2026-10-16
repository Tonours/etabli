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
Explicit markers such as `/goal`, `plan-loop`, `workflow`, `subagents`,
`jusqu'au bout`, `review`, or `verify` select specialized routes; they are not
required for ordinary bug fixes, feature work, reviews, or verification.

## Agentic workflow loop

Pi remains the primary user-facing tool. Thin adapters over shared contracts
(ADR-0006). Role chain: see `workflow/contract-details.md`. Shared
orchestration: `workflow/skills/orchestration.md`. One writer at any instant: the parent or one
`worker` per step; `scout` and `reviewer` stay read-only (Bash `PreToolUse` allowlist).
The multi-model council was removed (ADR-0013).

```text
user intent -> router -> planner -> challenger -> adversary -> implementer -> verifier -> reviewer -> reporter -> stop
```

## Statuses

`PLAN.md` uses one status:

- `DRAFT`: plan exists, not implementation-ready.
- `CHALLENGED`: review found blockers or vague scope/checks.
- `READY`: the canonical minimum contract is mechanically present and scope,
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
- Review: Logic hunter then Spec hunter; `GO` needs a filled deciding-code table
  for runtime diffs (`workflow/review-rubric.md`). An escaped defect after `GO`
  fills `workflow/templates/escaped-defect.md`.
- Cold contracts, opened only on their trigger: bounded re-review
  `workflow/skills/review-rounds.md` (findings, re-review, CI commits after
  review); open-ended improvement loops `workflow/skills/long-loop.md`.
- No-progress stop: when the same fix hypothesis fails twice, or the same check
  stays red three times with no new diff between runs, stop as `blocked`.
- READY plans stay editable: when Checks or Acceptance Criteria change, note
  why in the Decision Log. No runtime freeze.
- Autonomous loop stop conditions pair the measurable goal with an explicit
  operational cap (iterations or wall-clock). Global model-token totals are
  telemetry, never plan/goal stop conditions. Bounded payload contracts and
  explicit billing authorization remain separate. The final review of an
  autonomous `plan-implement` run comes from a fresh
  context (subagent reviewer or cross-model). Handoffs are recorded in
  `PLAN.md` § Notes / Handoff.
- Implementation depth is risk-tiered (`small` / `standard` / `high-risk`)
  per `workflow/skills/implementation-loop.md`: cross-model code-diff
  adversary is reserved for high-risk; standard accepts a documented
  same-family double-sample; small runs checks plus self-review.
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
- route, role, stop condition, and required evidence (every plan; the gate requires them unconditionally)
- known risks or explicit "none"
- facts separated from assumptions when the task depends on uncertain context
- populated requirement trace with a disposition for every material spec/code gap
- no blocking open questions
- no active raw HTML as semantic evidence; use Markdown text, inline code, fenced code,
  or explicit `command:` lines so the READY gate can evaluate content deterministically

## Routing rules

<!-- ROUTES:begin -->
| Trigger | Route | Artifact | Stop |
| --- | --- | --- | --- |
| Simple question or explanation | `answer` | none | answer delivered |
| Diagnosis, compare, or pre-existing-capture forensics | `answer` | none | answer delivered; do not write `PLAN.md` |
| Ordinary coding with no root `PLAN.md` and no explicit plan request | `answer` | code/docs | edit complete; do not skip READY/`plan-implement` when the user asked for a plan or the work is multi-slice |
| Broad task, unclear implementation, or "fais un plan" | `plan-loop` | `PLAN.md` | `READY` or `CHALLENGED` |
| Read-only adversarial PLAN.md review, or adversarial review with "do not edit" intent | `review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| Adversarial plan review | `adversary` | updated `PLAN.md` | `READY`, `CHALLENGED`, or blocker |
| Existing `READY PLAN.md` covering the requested task, plus implementation request | `implement` | code/docs + archive | validated archive and root `PLAN.md` deleted |
| "plan puis implémente", autonomous `plan-loop`, or equivalent | `plan-implement` | `PLAN.md` then code/docs | validated archive and root `PLAN.md` deleted |
| Self-improvement request from run evidence, recurring findings, or workflow failures | `plan-implement` | `PLAN.md` + workflow contract/router/check changes | validated archive and root `PLAN.md` deleted, or explicit no-op/blocker |
| Ambitious project, "A to Z", "de a a z", or end-to-end project request | `plan-implement` | `PLAN.md` + spec/slices/workflow artifacts/code/docs as needed | validated archive and handoff |
| Natural-language implementation request for a Linear ticket | `plan-implement` (`implement` with a READY plan) | `PLAN.md` from the ticket + code/docs + validation | validated archive and root `PLAN.md` deleted |
| Review request, including a GitHub PR review in natural language | `review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| Verify, retest, prove, or completion audit (interface `verify`; internal id `verify-workflow`) | `verify` | verification report | `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE` |
<!-- ROUTES:end -->

Work commands are explicit commands (work scope), never chosen by the
router: `/linear-work`, `/linear-ticket-create`, `/linear-project-setup`,
`/bug-check`, `/pr-council-review`. Slash prompts bypass the classifier, so each runs
under its own contract. Linear commands
require Linear MCP or stop with `LINEAR_MCP_UNAVAILABLE` — see
`docs/mcp-strategy.md`. Rationale: ADR-0027.

`verify` is the contract route; the Claude command surface names it
`/verify-workflow` and Pi presents `/skill:verify`.

A route says what to produce and when to stop; it does not say what the area
already taught us. Where the runtime exposes skills, select the narrowest domain
or project skill for the subject alongside the route — they are orthogonal, and
the skill keeps a route from rediscovering known ground. Optional domain skills
are **opt-in**: load one only when the runtime exposes it and the brief clearly
matches, never as a mandatory first step on `plan-loop` or `plan-implement`. A project skill wins over a generic language/framework skill when the
task is about the codebase. When no matching skill is exposed, the route still
follows its local-source fallback instead of silently skipping the phase.
Selection stays with the model, never injected per prompt (ADR-0014). There is
no additional global skill router.

## Human checkpoints

None. Deletion, production, billing, history rewrite, pushes, and external
write-back run without a stop (ADR-0032); secrets are never printed or
committed. Adapter coverage: routes shared by Pi extension and Claude hooks;
executable classifier `workflow/runtime/workflow-router-core.mjs` via
runtime-specific adapters.

Routing is deterministic code only (the semantic judgment layer was removed);
actual plan state and the remaining write gates (no-comments, read-only
agents) stay authoritative code.

## Runtime surfaces

Full index: `workflow/contract-details.md` § Runtime surfaces (detail). Key surfaces referenced by routing/guards: Claude hooks fragment
`claude/settings.workflow-hooks.json` and `workflow/plan-archive.md`.

## Daily loop

See `workflow/contract-details.md` § Daily loop (inspect → plan → READY →
adversary → implement → checks → review → archive → delete root PLAN.md).
