---
description: Plan, review, then implement only when PLAN.md is READY
argument-hint: [task description]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent, Skill]
---

# Plan Implement

User request: $ARGUMENTS

Follow `workflow/spec.md` and the shared contract in
`workflow/skills/implementation-loop.md`.

If the contract is missing in the workspace, try `~/.pi/agent/`, `~/.claude/`, then `~/.agents/` copies of the same relative path. If still missing, stop with `SHARED_CONTRACT_MISSING`.


## Autonomous chain

This command is the full-auto workflow. Run every phase in one uninterrupted
flow — never stop between phases to ask "continue?":

0. Skill selection: load the narrowest matching skill that this runtime
   actually exposes (for example a project skill, `frontend-css-ui-ux`, `node`,
   `vercel-react-best-practices`, or a task skill such as `bug-check`). If none
   is exposed, use the route contract's local-source fallback. Name the skill(s)
   used, or `none`, in the plan's `Notes / Handoff`.
1. Understand: scoped local recon of the affected area. Dispatch a `scout` when
   the area is unfamiliar enough that reading it would load files the plan does
   not need to keep; read it yourself when it is small. Carry the sourced
   findings into the plan either way.
2. Plan: create/refresh `PLAN.md`, self-critique to `READY` or `CHALLENGED`.
3. Adversary: run the cross-model pass non-interactively (`pi -p --model
   openai-codex/gpt-5.5 --tools read` piping `PLAN.md`, per `/adversary`;
   fallbacks `xai/grok-4.5` then `zai/glm-5.2`); fold accepted findings;
   continue only if still `READY`. If no cross-family model is available, run
   the adversary contract yourself and record that the pass was same-model.
4. Implement the `READY` plan steps in order; code behavior changes ship with
   their tests, bug fixes start from a failing test. Per step, either write it
   yourself or delegate it to one `worker`: delegate when the step needs files
   you have not read, keep it when you already hold the context. Name the choice
   and its reason in the ledger for every step. At most one `worker` runs at a
   time. Invoke it in the foreground; if the runtime backgrounds it, wait for the
   worker to finish and do not write until it returns. Then take the pen back and
   read `git diff` yourself: its report says where to look; the diff is what
   happened.
5. Run the plan checks, then the implementation-loop 12b simplification
   ladder (re-run checks if it edited anything). Record `simplify: clean` or
   `simplify: removed N`.
6. Quality pass (implementation-loop 12c): invoke `code-quality` when this
   runtime exposes it. Otherwise load the narrowest exposed domain or project
   skill, else compare the diff with 1-3 local siblings. If neither a skill
   nor a sibling exists, record `quality: unavailable` and stop before
   completion. Fix mechanical findings; report behavioral ones. Skip only for
   pure docs or plan-only changes, and say so.
7. Product dogfood when the plan requires it or the change is a user-facing
   product-flow (`workflow/skills/product-dogfood.md`).
8. Fresh-context review: pin the diff once, then dispatch the `reviewer` agent
   twice (Logic hunter template, Spec hunter template; parallel when the runtime
   can) per `workflow/skills/review.md`; fold blockers, rerun checks if needed.
9. Code-diff adversary: run the adversary Code diff mode cross-model on the
   implementation diff; in an autonomous run without a cross-model runner,
   stop as `blocked`.
10. Archive to `docs/plan/`, delete root `PLAN.md`, report the final handoff.

Record the event ledger (`.workflow/<slug>/events.jsonl`) across the run and
respect the no-progress and cap rules from `workflow/spec.md`.

Stops are limited to: `CHALLENGED` plan, blocker surviving adversary or review,
no-progress rule, missing validation surface, or a human checkpoint category
(destructive, production, secrets, external write-back).

Rules:

- Do not ask for confirmation once the plan is `READY`.
- Do not pause between phases for a go-ahead; the stop list above is exhaustive.
- Do not create `REVIEW.md`.
