# Using the Etabli workflow in daily development

Practical guide for humans and agents. Canonical contracts live in
`workflow/spec.md` and `workflow/topology.md`. This page is the short path.

## Activation

Any project that contains `workflow/spec.md` activates the workflow **ambiently**.

- You do **not** need to write “use the Etabli workflow”.
- Ordinary prompts are enough for small fixes, features, reviews, and verification.
- Explicit markers (`/plan-loop`, `/plan-implement`, `/goal`, `review`, `verify`…)
  select specialized routes when you want more control.

`PLAN.md` at the project root is the **only** active execution artifact.
Implementation is allowed only when its status is `READY`.

## Golden rules

1. One writer: the parent agent. Sidecars (scout/council) are read-only.
2. One plan: root `PLAN.md`. Archive finished work under `docs/plan/`, then delete the root file.
3. READY is the gate. Draft or Challenged plans do not authorize code changes.
4. Prefer the smallest route that can finish with evidence.
5. Destructive / secret / production / external write-back → human checkpoint (`ops-stop`).
6. Claims stay proportional to evidence (`confirmed` / `proxy_supported` / `blocked` / `unknown`).

## Commands cheat-sheet

### Claude Code (slash commands)

| Command | When to use | Stops at |
| --- | --- | --- |
| *(normal prompt)* | Small bug, simple change, question | Answer or minimal change |
| `/plan` | Create a plan only | `DRAFT` |
| `/plan-loop` | Plan + challenge until ready or blocked | `READY` or `CHALLENGED` |
| `/adversary` | Stress-test an existing plan before coding | Updated `PLAN.md` |
| `/implement` | Execute an existing `READY` plan | Validated archive + root `PLAN.md` removed |
| `/plan-implement` | Full autonomous chain (plan → adversary → implement → review → archive) | Same as implement |
| `/review` | Review current diff | `GO` / `GO WITH NOTES` / `BLOCK` |
| `/verify-workflow` | Prove claims or re-run checks without editing | `VERIFIED` / … |
| `/pr-review` | Review a GitHub PR | Findings only |
| `/pr-qa` | QA plan for a PR | Executable test plan |
| `/sec-pr` | Dependabot / security PR audit | `PASS` / `FAIL` / `INVESTIGATE` |
| `/ci-fix` | Explicit autonomous CI repair | CI green or blocked / cap |
| `/linear-ticket-create` | Create a Linear ticket | Issue created |
| `/linear-work` | Work from a Linear ticket | Acceptance validated or blocked |
| `/bug-check` | Root-cause a Linear bug without coding | Confidence label |
| `/goal <condition>` | Long-running completion loop (with explicit cap) | Goal met or blocked |
| `/ship` | Explicit A-to-Z delivery (consents to branch push + PR) | Ship contract |

Manual-only (never ambient): `/commit`, `/pre-commit`, `/recap`, `/ui-debug`, …

### Pi (skills)

| Skill | Equivalent intent |
| --- | --- |
| `/skill:plan-loop <task>` | Same as Claude `/plan-loop` |
| `/skill:plan-implement <task>` | Same as Claude `/plan-implement` |
| `/skill:adversary` | Same as `/adversary` |
| `/skill:implement` | Same as `/implement` |
| `/skill:review` | Same as `/review` |
| `/skill:verify` | Same as `/verify-workflow` |
| `/skill:pr-review`, `/skill:pr-qa`, `/skill:sec-pr`, `/skill:ci-fix` | PR / CI routes |
| `/skill:linear-ticket-create`, `/skill:linear-work`, `/skill:bug-check` | Linear routes |

Pi also has adaptive multi-model (scout / council) under
`workflow/skills/multi-model-orchestration.md`. Parent stays the only writer.

### Host scripts (outside the agent)

```bash
scripts/verify-agentic-infra core   # daily health
scripts/verify-agentic-infra full   # all deterministic checks
scripts/vnext-suite --json          # control-plane regression
scripts/plan-check-freeze --current PLAN.md --previous PLAN.snapshot.md
scripts/answer-quality-check path/to/artifact.md
scripts/deploy-agent-workflow --dry-run
```

## Typical daily flows

### 1. Tiny fix / clear bug (ambient)

Just ask:

> Fix the null check in `src/foo.ts` and run the focused test.

Router picks a small path. No `PLAN.md` required if the change is obviously bounded.

### 2. Non-trivial feature or refactor

```text
You: "Add X. Plan first."
→ /plan-loop (or ambient plan-loop)
→ review PLAN.md until Status: READY
→ /implement   (or continue with plan-implement)
→ focused checks + review
→ archive under docs/plan/ ; root PLAN.md deleted
```

### 3. Autonomous end-to-end

```text
You: /plan-implement Add user export CSV with tests
```

or on Claude:

```text
You: /goal Export users as CSV; stop after tests green or 4 attempts
```

Autonomous routes must leave an event ledger under `.workflow/<slug>/`.

### 4. Review only

```text
You: /review
# or
You: Review the current diff against the plan; do not edit
```

### 5. PR / CI / Linear

Use the dedicated commands (`/pr-review`, `/ci-fix`, `/linear-work`…).  
They carry their own HITL contracts for external write-back.

### 6. Risky or irreversible work

Anything destructive, secret-related, production, or broad external write is
routed to **ops-stop**. The agent produces a risk brief and waits for you.

## How to choose the route

| Situation | Prefer |
| --- | --- |
| One-line fix, obvious check | Ambient prompt |
| Scope unclear or multi-file | `/plan-loop` then `/implement` |
| You want the agent to finish the whole loop | `/plan-implement` or `/goal` |
| Plan already `READY` | `/implement` |
| You only want findings | `/review`, `/verify-workflow`, `/pr-review` |
| CI red and you explicitly want auto-repair | `/ci-fix` |
| Linear ticket driven work | `/linear-work` |

## Statuses of `PLAN.md`

- `DRAFT` — not ready to code
- `CHALLENGED` — blockers or weak checks; fix the plan
- `READY` — implementation authorized

Once `READY`, **check-freeze** applies: Checks may only be strengthened.
To remove or weaken a check, demote to `CHALLENGED` and record a Decision Log
rationale (`scripts/plan-check-freeze` enforces this mechanically).

## After the work is done

1. Focused checks green
2. Review against the plan
3. Archive distilled plan under `docs/plan/`
4. Delete root `PLAN.md`
5. Commit only when you asked for a commit

## Where to go deeper

| Need | File |
| --- | --- |
| Full contract | `workflow/spec.md` |
| Graph of nodes & edges | `workflow/topology.md` |
| Loop patterns | `workflow/loop-patterns.md` |
| Answer quality floor | `workflow/answer-quality.md` |
| Self-improvement | `workflow/skills/self-improvement-loop.md` |
| Ambitious project | `workflow/skills/ambitious-project-loop.md` |
| PR maintenance | `workflow/skills/pr-maintenance-loop.md` |
| Multi-model | `workflow/skills/multi-model-orchestration.md` |
| Capabilities honesty | `workflow/runtime-capabilities.json` |

## Short daily checklist

1. Open the project (workflow ambient if `workflow/spec.md` exists).
2. State the goal in plain language (or use an explicit slash skill).
3. If scope is large → force a plan until `READY`.
4. Let implement run only on `READY`.
5. Demand focused evidence, not full-suite theatre.
6. Keep irreversible actions behind your explicit OK.
