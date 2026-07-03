# Workflow 101

Introduction to the Etabli workflow. The canonical contract stays in
`workflow/spec.md`; this guide is the pragmatic on-ramp. Once the loop feels
natural, switch to the spec for edge cases and exact rules.

## What it is

Etabli gives every agent the same shape of work: one shared **plan**, a hard
gate before editing, focused checks, and a memory trail. The point is to stop
agents from editing code on a vague prompt, and to leave durable state behind.

- **One execution artifact**: `PLAN.md` at the repo root. No `REVIEW.md`, no
  side docs.
- **Three statuses**: `DRAFT`, `CHALLENGED`, `READY`. Only `READY`
  authorizes implementation; archives are durable records, not plan statuses.
- **Two harnesses, one contract**: Pi skills and Claude commands are thin
  adapters over the same `workflow/skills/` contracts.

The workflow is ambient: if a repo contains `workflow/spec.md`, you should not
need to write "use the Etabli workflow" in every prompt. Say the task normally;
the agent should pick the smallest route that can finish with evidence.

## The loop in one picture

```text
plan-loop → adversary → implement → validate → review → archive → cleanup
```

| Step | What happens | Stop point |
| --- | --- | --- |
| `plan-loop` | create/refine `PLAN.md`, critique scope & checks | `READY` or `CHALLENGED` |
| `adversary` | stress-test a READY plan before editing | `READY` holds, or `CHALLENGED` |
| `implement` | execute READY steps in order, minimal drift | checks green |
| `validate` | run the focused checks named in the plan | pass / fail |
| `review` | read-only diff check: correctness, drift, safety | `GO` / `GO WITH NOTES` / `BLOCK` |
| `archive` | distill the implemented plan into `docs/plan/` | memory record written |
| `cleanup` | delete the root `PLAN.md` after archive + validation | root plan removed |

Not every task runs the full loop. A simple question never touches `PLAN.md`.
The router picks the smallest loop that can finish with evidence.

## Your first task: "implement this"

The most common path is **plan then implement**, in one autonomous run.

Pi:

```text
/skill:plan-implement refactor the auth module
```

Claude:

```text
/plan-implement refactor the auth module
```

What happens, in order:

1. The agent inspects repo state and relevant files.
2. It writes `PLAN.md` with `Status: DRAFT`, fills goal, scope, steps, checks,
   risks.
3. It critiques the plan against the READY gate (below) and flips to
   `Status: READY` or `Status: CHALLENGED`.
4. It runs the adversary pass, folds accepted findings, keeps `READY` only if
   no blocker remains.
5. It implements the steps in order, runs the named checks, reviews the diff.
6. It archives the implemented plan to `docs/plan/YYYYMMDD-slug.md` and deletes
   the root `PLAN.md`.

If you only want the plan (no code yet), use `plan-loop` and stop at `READY`.
If a `READY` plan already exists and you just want it executed, use `implement`.

## The READY gate

A plan is `READY` when it has:

- a clear goal
- bounded scope (and non-goals when the task is broad)
- concrete steps, with named files/areas for risky changes
- checks to run (commands, not vibes)
- route, role, stop condition, and required evidence for non-trivial work
- known risks, or an explicit "none"
- facts separated from assumptions when the context is uncertain
- no blocking open questions

**Never implement from `DRAFT` or `CHALLENGED`.** This is the single rule that
prevents most drift.

### "PLAN.md ready" in a prompt is not proof

If you type *"implement the PLAN.md, it's ready"*, the router does **not** trust
the wording. It reads the actual `Status:` line in the root `PLAN.md`. Prompt
wording is routing context; the gate is the status recorded in the file. If the
file is missing or not `READY`, you get `plan-implement` (which plans first),
never a straight `implement`.

## The adversary pass

Run before implementation, never after. The adversary treats the plan as guilty
until proven sound and hunts for:

- blockers and weak assumptions
- missing validation or weak required evidence
- edge cases and plan drift against current repo state
- simpler or safer routes

Each finding is accepted or rejected with concrete evidence; accepted findings
fold back into `PLAN.md`. `READY` survives only if no blocker or high-severity
issue remains. In Claude, `/adversary` can delegate the critique to Codex for a
cross-model second opinion — same contract, different model family.

The adversary reviews the **plan**. For read-only adversarial PLAN.md review or
post-implementation diff review, use `/skill:review` (Pi) or `/review`
(Claude).

## The router

You rarely pick the route by hand. When you send a plain prompt (not a slash
command), the router classifies it and injects context: the route, its artifact,
its stop condition, and the required evidence.

Use explicit markers only when you want the heavier path: `/goal`,
`plan-loop`, `subagents`, `workflow`, or "jusqu'au bout". For ordinary work,
"corrige le bug et valide" is enough.

A few examples:

| You type | Route | Artifact |
| --- | --- | --- |
| "fais un plan pour X" | `plan-loop` | `PLAN.md` |
| "implémente X" | `plan-implement` | `PLAN.md` then code |
| "review le diff" | `review` | findings |
| "prouve que les tests passent" | `verify` | verification report |
| "corrige le bug Linear LIN-42" | `linear-work` | `PLAN.md` + code |
| "supprime ce dossier de prod" | `ops-stop` | risk brief (stops for your decision) |

The router is alignment-tested across Pi and Claude, so the same prompt routes
the same way in both harnesses. You can always override it by invoking a skill
or command directly.

## Where to go next

- `workflow/spec.md` — the full contract: every route, status, and rule.
- `workflow/skills/implementation-loop.md` — the implementation sequence shared
  by Pi and Claude adapters.
- `workflow/skills/adversary.md` — the adversary contract.
- `workflow/skills/orchestration.md` — capability labels, delegation, retry,
  fallback, and acceptance evidence for long-running orchestration.
- `PLAN_TEMPLATE.md` — the default lightweight plan shape.
- `PLAN_TEMPLATE_FULL.md` — the full plan for broad or risky work.
- `workflow/review-rubric.md` — review output format and priorities.
- `docs/pi-cheatsheet.md` — Pi commands and config at a glance.
