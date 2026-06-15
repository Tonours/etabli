# Pi Agentic Workflow Loop Plan

Research date: 2026-06-14.

## Objective

Build a more deterministic agentic workflow loop on top of Pi without replacing
Pi, wrapping Pi, or bringing back the old ambiguous label.

Deterministic does not mean the model becomes perfectly predictable. It means
the workflow reduces variance by constraining decisions through visible role
contracts, templates, routing rules, validation gates, and stop conditions.

## Current Local Baseline

### Confirmed

- `AGENTS.md` maps the repo and points to the workflow sources of truth:
  `workflow/spec.md`, `PLAN_TEMPLATE.md`, `PLAN_TEMPLATE_FULL.md`, and
  `workflow/review-rubric.md`.
- `pi/AGENTS.md` already defines the desired operator posture: French, concise,
  evidence-first, small reversible steps, focused checks, and preservation of
  unrelated changes.
- `workflow/spec.md` defines the current loop:
  `learn -> plan -> implement -> review -> validate`.
- `PLAN.md` already has explicit states: `DRAFT`, `CHALLENGED`, `READY`.
  Implementation is allowed only from `READY`.
- `pi/agent/settings.json` loads the local extensions `rtk.ts`,
  `filter-output.ts`, `block-google-providers.ts`, and `tasks-till-done.ts`.
- `pi/agent/settings.json` loads the local skills `plan-loop`,
  `plan-implement`, `review`, `implement`, `caveman`, and `grill-me`.
- `plan-loop` creates/reviews `PLAN.md` and must not implement.
- `plan-implement` plans first, implements only if `PLAN.md` is `READY`,
  archives implemented plans, then deletes root `PLAN.md` after validation.
- `implement` implements an existing `READY` `PLAN.md` without rerunning full
  planning.
- `review` is read-only and reports findings grounded in the current diff.
- `tasks-till-done` injects hidden task-loop guidance when Task* tools are
  available and the prompt is action-oriented, then auto-continues while
  `TaskList` shows actionable work.
- `workflow-scaffold` is now the portable project workflow kit, not the Pi loop.

### Gaps

- The Pi-native deterministic loop is not documented as one coherent system.
- Routing rules are implicit across skills and user memory.
- Roles exist as behavior, but not as explicit contracts:
  router, planner, challenger, implementer, verifier, reviewer, reporter.
- `tasks-till-done` understands task status, but not workflow phase or required
  validation evidence.
- There is no dedicated `verify` skill.
- There is no fixture suite proving that prompts route to the expected skill,
  status, or stop condition.

## Source-Backed Findings

### Confirmed

- Anthropic describes useful agent workflows as composable patterns, including
  orchestrator-workers for unpredictable subtasks and evaluator-optimizer for
  generate/evaluate loops:
  https://www.anthropic.com/engineering/building-effective-agents
- Anthropic's long-running application development work used
  planner/generator/evaluator separation, tractable chunks, and structured
  handoff artifacts:
  https://www.anthropic.com/engineering/harness-design-long-running-apps
- OpenAI recommends eval baselines, clear tool definitions, explicit run-loop
  exit conditions, prompt templates before extra multi-agent complexity, and
  adding multiple agents only when single-agent instructions or tool selection
  become unreliable:
  https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
- OpenAI Codex Goals formalize the same concept as a completion contract:
  outcome, verification surface, constraints, boundaries, iteration policy, and
  blocked stop condition:
  https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex
- OpenAI agent eval docs recommend traces first for debugging, then repeatable
  datasets/eval runs once good behavior is defined:
  https://developers.openai.com/api/docs/guides/agent-evals
- OpenAI guardrail docs define automatic checks and human review as controls for
  whether a run continues, pauses, or stops:
  https://developers.openai.com/api/docs/guides/agents/guardrails-approvals
- OpenAI's evaluation flywheel treats prompt reliability as analyze, measure,
  improve:
  https://developers.openai.com/cookbook/examples/evaluation/building_resilient_prompts_using_an_evaluation_flywheel
- Structured-output docs from OpenAI and Anthropic support schema-based output
  contracts where the runtime supports them:
  https://developers.openai.com/api/docs/guides/structured-outputs
  https://platform.claude.com/docs/en/build-with-claude/structured-outputs
  https://platform.claude.com/docs/en/agents-and-tools/tool-use/strict-tool-use
- Anthropic Agent Skills docs support the current skill direction: package
  domain expertise, instructions, scripts, and references with progressive
  disclosure:
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Claude Code hooks show the deterministic layer principle: lifecycle hooks can
  enforce actions every time, while skills and prompts guide model judgment:
  https://code.claude.com/docs/en/hooks-guide
- Pi is designed to be customized through extensions, skills, prompt templates,
  themes, and packages; Pi deliberately keeps sub-agents and plan mode out of
  the core:
  https://pi.dev/
- Pi skills are on-demand capability packages with `/skill:name` commands and
  progressive disclosure:
  https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md
- Pi extensions can inspect/modify the system prompt and react to lifecycle
  events such as `before_agent_start` and `agent_end`:
  https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md

### Proxy-Supported

- MCP tool-description research suggests that names, descriptions, and schemas
  materially affect agent tool selection and task success. This is not Pi-
  specific, but it supports treating skill descriptions and tool prompts as test
  surfaces:
  https://arxiv.org/html/2602.14878v1
- LangGraph, Microsoft Agent Framework, Google ADK, DSPy, ReAct, and AutoGen all
  support pieces of the design vocabulary: durable state, explicit workflows,
  evals, tool/action loops, and multi-agent composition. They are references,
  not dependencies for this Pi-native plan.

### Approximate

- No implementation recommendation in this plan depends on approximate-only
  evidence. Exact support level should be rechecked when implementing a specific
  Pi extension API or third-party package.

### Blocked

- No research claim is blocked. The implementation remains blocked only by
  future user approval when runtime changes are requested.

### Unknown

- Whether Pi's current Task* tools expose enough structured state to enforce
  phase-aware validation without parsing text output.
- Whether Pi has a stable replay interface suitable for full transcript evals.
  If not, start with unit tests around routing functions and extension behavior.
- Whether sub-agent packages for Pi are mature enough for daily use. Do not
  depend on them for the first implementation.

## Design Principle

Use this escalation ladder:

1. Visible docs and templates for shared human/model understanding.
2. Skills for role-specific protocols.
3. Prompt templates for repeatable user entry points.
4. Pi extensions for lifecycle automation that must happen reliably.
5. Local eval fixtures and tests for regression evidence.
6. Dedicated subagents only after fixture evidence shows role separation helps.

Do not jump to step 6 because it sounds cleaner. More agents add more decision
surfaces unless their inputs, outputs, and stop conditions are explicit.

## Target Operating Model

```text
User intent
  -> Router contract
  -> Planner contract
  -> Challenger contract
  -> Implementer contract
  -> Verifier contract
  -> Reviewer contract
  -> Reporter contract
  -> Stop: done, blocked, or explicitly out of scope
```

Pi remains the main tool. Each "agent" is first a role contract expressed as a
skill, template, or extension behavior.

## Role Contracts

### Router

Purpose: classify the request into the smallest valid workflow.

Inputs:

- user prompt;
- current repo state;
- presence/status of root `PLAN.md`;
- explicit skill invocation;
- available Task* tools.

Outputs:

- selected mode: `answer`, `plan`, `implement-ready-plan`, `plan-implement`,
  `review`, `verify`, `research-plan`, `ops-stop`;
- reason;
- required artifact;
- stop condition.

Rules:

- Explicit `/skill:*` wins.
- Existing `READY PLAN.md` plus "implémente" routes to `implement`.
- Broad/unclear work routes to `plan-loop`.
- Review requests route to `review` and stay read-only.
- Research requests with sources route to a research-plan workflow and produce a
  cited document.
- Destructive, production, secret, billing, or deployment work pauses for a
  user decision.

### Planner

Use existing `plan-loop`.

Contract:

- reads relevant local files before planning;
- creates/refreshes root `PLAN.md`;
- starts with `DRAFT`;
- critiques the plan;
- ends as `READY` or `CHALLENGED`;
- does not implement;
- does not archive.

Needed improvement:

- add a small "Role / Route" section to plan templates for broad work:
  `router decision`, `required verifier`, `stop condition`.

### Challenger

Purpose: reduce plan optimism before implementation.

Default implementation:

- keep inside `plan-loop` for now;
- extract into `plan-challenge` only if repeated failures show the combined
  planner/challenger role is too weak.

Checklist:

- scope too broad;
- missing checks;
- assumptions pretending to be facts;
- no rollback point for risky work;
- implementation steps not sequential;
- hidden dependency on user context;
- no clear done evidence.

### Implementer

Use existing `implement` and `plan-implement`.

Contract:

- may implement only from `READY`;
- follows plan steps in order;
- updates `PLAN.md` only when facts change;
- runs checks named in the plan;
- archives only after implementation and validation;
- deletes only root `PLAN.md` after successful archive.

Needed improvement:

- include "plan drift detected" as an explicit stop state when new facts change
  the plan materially.

### Verifier

New skill: `verify`.

Purpose: run or inspect validation evidence without adding new behavior.

Contract:

- reads `PLAN.md` if present;
- derives expected evidence from acceptance criteria and checks;
- runs only focused commands unless asked to broaden;
- verifies source links for docs/research tasks;
- verifies task-loop completion state when Task* tools are available;
- returns `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE`.

Non-goal:

- no code edits;
- no style review unless it affects the evidence.

### Reviewer

Use existing `review`.

Contract:

- read-only;
- findings first;
- grounded in diff lines;
- checks correctness, regressions, safety, validation, maintainability, and plan
  drift;
- ends with `GO`, `GO WITH NOTES`, or `BLOCK`.

### Reporter

Purpose: leave durable state after work.

Current pieces:

- implementation archive in `docs/plan/`;
- workflow scaffold `docs/project-context.md`;
- optional agent memory in `docs/agent-memory/`.

Needed improvement:

- add a small reporting checklist to implementation final output:
  files changed, validations, archive path, deleted `PLAN.md` status, remaining
  risks, next action if any.

## Routing Rules

| Trigger | Route | Artifact | Stop |
| --- | --- | --- | --- |
| "explique", simple question | answer | none | answer delivered |
| "fais un plan", broad task | `plan-loop` | `PLAN.md` | `READY` or `CHALLENGED` |
| existing `READY PLAN.md` + "implémente" | `implement` | code/docs + archive | validated archive + root `PLAN.md` deleted |
| "plan puis implémente" | `plan-implement` | `PLAN.md` then code/docs | validated archive + root `PLAN.md` deleted |
| "review" | `review` | findings only | `GO`, `GO WITH NOTES`, or `BLOCK` |
| "vérifie", "retest", "prouve" | `verify` | evidence report | `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE` |
| research + sources | research-plan protocol | doc under `docs/` | cited artifact complete |
| destructive/secret/prod/deploy | ops-stop | risk brief | user decision |
| Task* active + actionable request | `tasks-till-done` assists | TaskList | all tasks done/blocked/stalled/limit |

## Templates To Add Or Modify

### Modify `PLAN_TEMPLATE.md`

Add:

```md
## Workflow Contract
- Route:
- Role:
- Stop condition:
- Required evidence:
```

### Modify `PLAN_TEMPLATE_FULL.md`

Add:

```md
## Workflow Contract
- Router decision:
- Planner output:
- Challenger focus:
- Implementer boundaries:
- Verifier checks:
- Reporter artifact:
- Stop conditions:
```

### Add `workflow/router-template.md`

Purpose: source of truth for routing decisions.

Shape:

```md
# Router Decision

## Input
- Prompt:
- Repo state:
- Existing artifact:

## Decision
- Route:
- Reason:
- Skill/template:
- Artifact:
- Stop condition:

## Blockers
- None / ...
```

### Add `workflow/verification-report-template.md`

Shape:

```md
# Verification Report

## Verdict
VERIFIED | NOT VERIFIED | INCONCLUSIVE

## Evidence Checked
- command/source:
  - expected:
  - observed:

## Gaps
- None / ...

## Next Action
-
```

## Skills To Add Or Update

### Add `pi/skills/verify`

Priority: P1.

Why: validation is the strongest way to reduce variance. A dedicated verifier
prevents "implemented" from meaning "felt done".

Acceptance:

- Given a root `PLAN.md` with checks, when `/skill:verify` runs, then it reports
  each check as passed, failed, skipped, or inconclusive.
- Given no `PLAN.md`, when asked to verify a diff or claim, then it derives a
  bounded evidence list and does not edit files.
- Given insufficient evidence, then it returns `INCONCLUSIVE` with the missing
  evidence.

### Update `plan-loop`

Priority: P1.

Add:

- explicit router decision in `PLAN.md`;
- explicit stop condition;
- explicit verifier requirement for risky/broad work.

### Update `implement`

Priority: P1.

Add:

- explicit `plan drift` stop rule;
- call out when checks are missing from the plan before implementation starts.

### Optional Add `pi/skills/plan-challenge`

Priority: P2, only if evidence shows `plan-loop` remains too optimistic.

Purpose:

- review `PLAN.md` only;
- set `CHALLENGED` or confirm `READY`;
- no implementation.

### Optional Add `pi/skills/research-plan`

Priority: P2.

Purpose:

- produce sourced docs;
- classify claims;
- avoid code edits;
- enforce primary/recognized sources for technical claims.

This can also be a prompt template instead of a skill if usage stays occasional.

## Extensions To Add Or Update

### Update `tasks-till-done`

Priority: P1.

Current value:

- continues until TaskList has no actionable work.

Needed changes:

- log the workflow route when known;
- surface stop reason in a concise visible final note when it stops by limit,
  stalled, or blocked;
- optionally require a validation task before final completion when tasks were
  created from an implementation request.

Acceptance:

- Given actionable pending tasks, it continues.
- Given all tasks complete, it stops.
- Given only blocked tasks, it stops and reports blocker.
- Given repeated identical TaskList signatures, it stops as stalled.
- Given an implementation task with no validation task, it nudges creation of a
  validation task before completion.

### Add `pi/extensions/workflow-router.ts`

Priority: P2.

Purpose:

- append small hidden routing guidance at `before_agent_start`;
- do not override explicit skill commands;
- keep visible source of truth in `workflow/spec.md` and templates;
- emit a custom entry with detected route for debugging.

Why extension, not just `AGENTS.md`:

- `AGENTS.md` guides the model.
- A lifecycle extension can consistently inject the same compact route contract
  for relevant prompts and can be unit-tested.

Non-goal:

- do not build a second task engine;
- do not auto-run skills without user or model action unless Pi exposes a stable
  supported command mechanism.

### Optional Add `pi/extensions/workflow-trace.ts`

Priority: P3.

Purpose:

- record route, phase, stop reason, checks run, and changed files as Pi custom
  entries.

Use only if this produces useful eval data without cluttering sessions.

## Prompt Templates

Add under Pi prompts only if Pi prompt-template loading is confirmed in the local
agent settings or installer.

Candidates:

- `/research-plan`: source-backed research plan, claims classified.
- `/verify`: evidence-first verification prompt.
- `/bugfix-plan`: bugfix-specific plan with reproduction and regression check.
- `/done-report`: concise final handoff format.

Avoid creating prompt templates for flows already covered by skills.

## System Prompt Decision

Do not add a broad `SYSTEM.md` now.

Reason:

- Pi already loads `AGENTS.md`, skills, and prompt templates.
- Large persistent system prompts are harder to test and easier to let drift.
- Pi extensions can append small, scoped guidance only when the prompt warrants
  it.

Add `SYSTEM.md` later only if:

- a project needs per-project hard behavior that cannot live in `AGENTS.md`;
- the behavior is stable enough to apply to every turn;
- a test or manual fixture proves it improves routing or completion.

## Eval Plan

### Unit Tests

Add tests for any pure routing/runtime helpers:

- prompt -> route;
- route -> skill guidance;
- TaskList -> continuation decision;
- stop reason -> final behavior.

### Golden Prompt Fixtures

Create fixtures such as:

- "fais une review de notre roadmap" -> review/research doc, no code edits.
- "implémente le PLAN.md ready" -> `implement`, not `plan-loop`.
- "corrige tout y compris warnings" -> task loop + validation required.
- "fais un prompt goal" -> prompt artifact only.
- "supprime X" -> require exact target and deletion risk check.
- "retest" -> infer latest validation target or ask one question if ambiguous.

Each fixture should assert:

- expected route;
- expected artifact;
- allowed write scope;
- stop condition.

### Real-Condition Tests

After implementation, run:

- `bash tests/fix-links-smoke.sh`
- `bash tests/install-smoke.sh`
- `cd pi && bun test ./extensions/__tests__/*.test.ts`
- a manual Pi session using Task* tools for one small implementation request;
- a manual Pi session for `READY PLAN.md` -> `implement`;
- a manual Pi session for review-only request -> no edits.

## Implementation Order

### Phase 0: Name And Contract

Deliverable:

- keep this doc as the planning source;
- avoid the old ambiguous terminology in new docs.

Status:

- done by this artifact.

### Phase 1: Visible Contracts

Changes:

- update `workflow/spec.md` with the role model and routing table;
- update `PLAN_TEMPLATE.md`;
- update `PLAN_TEMPLATE_FULL.md`;
- add `workflow/verification-report-template.md`;
- add `workflow/router-template.md`.

Validation:

- markdown smoke checks;
- `rg` for forbidden ambiguous terminology in new surfaces.

### Phase 2: Verifier Skill

Changes:

- add `pi/skills/verify/SKILL.md`;
- add installer/symlink consistency if skills are listed centrally;
- add tests ensuring configured local skills match installer declarations.

Validation:

- `bash scripts/check-fix-symlinks.sh --verbose`;
- `cd pi && bun test ./extensions/__tests__/settings-consistency.test.ts`.

### Phase 3: Existing Skill Tightening

Changes:

- update `plan-loop` to write the workflow contract fields;
- update `implement` and `plan-implement` with explicit plan-drift stops;
- update `review` only if the routing contract needs a standard verifier link.

Validation:

- manual dry run on a tiny fake `PLAN.md`;
- skill text review for contradictions with `workflow/spec.md`.

### Phase 4: Router Runtime

Changes:

- add a small pure routing helper under `pi/extensions/lib/`;
- add `workflow-router.ts` only after the helper behavior is tested;
- register it in `pi/agent/settings.json` and local settings if desired.

Validation:

- unit tests for route classification;
- `cd pi && bun test ./extensions/__tests__/*.test.ts`;
- manual Pi checks for explicit `/skill:*` not being overridden.

### Phase 5: Task Loop Evidence

Changes:

- extend `tasks-till-done` to nudge validation tasks and report stop reasons;
- keep auto-continue limits and stalled guards.

Validation:

- existing task loop tests plus new cases for validation nudges and stop
  reporting.

### Phase 6: Eval Fixtures

Changes:

- add prompt fixture data;
- add a lightweight test runner if Pi replay is unavailable;
- classify fixtures by route and expected stop.

Validation:

- fixture runner passes;
- at least one failed fixture demonstrates the suite can catch drift.

### Phase 7: Optional Dedicated Subagents

Gate:

- only after phases 1-6 show which roles still fail in real use.

Allowed:

- use Pi-native packages if stable;
- delegate only disjoint work;
- require explicit packet contracts.

Rejected for now:

- external orchestration runtime around Pi.

## Risks And Mitigations

- Risk: More roles increase cognitive load.
  Mitigation: role contracts are defaults, not mandatory visible ceremony for
  tiny tasks.
- Risk: Hidden routing guidance conflicts with visible docs.
  Mitigation: keep source of truth in `workflow/spec.md`; test extension output.
- Risk: Task loop continues without real progress.
  Mitigation: existing max-continue and stalled guards stay mandatory.
- Risk: Verification becomes ritual.
  Mitigation: verifier must report skipped/inconclusive evidence instead of
  pretending every task has tests.
- Risk: Multi-agent enthusiasm adds variance.
  Mitigation: subagents are Phase 7 and require evidence from fixtures.

## Acceptance Criteria

- Given a broad request, when Pi plans, then `PLAN.md` records route, role, stop
  condition, and required evidence.
- Given a `DRAFT` or `CHALLENGED` plan, when implementation is requested, then
  Pi stops with blockers instead of editing.
- Given a `READY` plan, when implementation is requested, then Pi follows
  `implement` without rerunning full planning.
- Given a review request, when Pi responds, then it performs read-only review and
  reports findings first.
- Given an implementation request with Task* tools, when tasks remain actionable,
  then `/tasks` continues until completion, blocked state, stalled state, or
  limit.
- Given completion is claimed, when verifier evidence is missing, then the result
  is `INCONCLUSIVE`, not done.
- Given a routing or skill change, when fixture tests run, then expected prompt
  routes and stop conditions remain stable.

## Recommended First Ticket

```md
## Outcome

Pi workflow planning records an explicit route, role, stop condition, and
required evidence in `PLAN.md`.

## Why now

- Milestone: deterministic agentic workflow loop
- Priority: P1
- Depends on: this plan
- Unblocks: verifier skill, router extension, fixture evals

## User story

As a Pi user, I want each non-trivial plan to state how it should be executed
and stopped so that implementation does not drift after context switches.

## Start here

- [ ] Update `PLAN_TEMPLATE.md` with a small `Workflow Contract` section.

## Context

- Repo/workspace: `/Volumes/Crucial/work/etabli`
- Relevant docs: `workflow/spec.md`, `PLAN_TEMPLATE.md`,
  `PLAN_TEMPLATE_FULL.md`, `pi/skills/plan-loop/SKILL.md`
- Likely files: workflow docs and Pi skills only
- Existing state: planning already uses `DRAFT`, `CHALLENGED`, `READY`

## Scope

- [ ] One template/skill contract change.
- [ ] No runtime extension changes.

## Non-goals / parking lot

- Do not build router extension yet.
- Do not add subagents.
- Do not change Task* behavior.

## Contract

Every broad or implementation-bound `PLAN.md` includes route, role, stop
condition, and required evidence.

## Edge cases

- Tiny docs/question tasks may not need a full plan.
- Existing `PLAN.md` should be refreshed without losing observed facts.

## Acceptance criteria

- [ ] Given `plan-loop` creates a plan, when the task is non-trivial, then the
  plan includes `Workflow Contract`.
- [ ] Given a plan lacks required evidence, when challenged, then it cannot be
  marked `READY`.
- [ ] Given the task is review-only, when planned, then implementation is out of
  scope.

## Implementation checklist

- [ ] Inspect current templates and skill text.
- [ ] Add the smallest viable template fields.
- [ ] Update `plan-loop` instructions to fill/challenge those fields.
- [ ] Run focused smoke checks.

## Validation

- [ ] Command/manual check: generate or inspect a sample plan.
- [ ] Test: existing Pi extension/settings tests still pass if touched.

## Stop conditions

Pause and ask before continuing if this requires runtime routing or changes to
Pi packages.

## Definition of done

- [ ] Acceptance criteria verified.
- [ ] Validation noted in final handoff.
```
