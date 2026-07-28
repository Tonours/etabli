# Using the Etabli Workflow in Daily Development

This guide explains how to use the Etabli agent workflow in everyday development.
It complements the canonical contract (`workflow/spec.md`) and the topology map
(`workflow/topology.md`).

## Activation

The workflow is **ambient**. Any project that contains `workflow/spec.md`
activates it automatically.

You do **not** need to write “use the Etabli workflow” in ordinary prompts.
Just describe the task; the router selects the smallest matching route.

Rules that always apply:

- One execution artifact: root `PLAN.md`
- Implementation starts only when `Status: READY`
- The parent agent is the only writer of durable mutations
- Push, deploy, destructive actions, secrets, production changes, and external
  write-back require explicit authority (or an explicit command contract such as
  `/ci-fix` or `/ship`)

## Golden path (daily loop)

1. Inspect repo state and read the relevant files.
2. If the work is non-trivial → create / refresh `PLAN.md`.
3. Get the plan to `READY` (plan-loop + adversary when needed).
4. Implement only from a `READY` plan.
5. Run focused checks.
6. Review the diff against the plan.
7. Archive the implemented plan under `docs/plan/` and delete the root `PLAN.md`.
8. Commit only when verified (and when you asked for a commit).

## When to use which route

| Situation | Route / command | Notes |
| --- | --- | --- |
| Simple question / explanation | just ask (route `answer`) | No plan required |
| “Fais un plan”, unclear scope, broad task | `plan-loop` | Stops at `READY` or `CHALLENGED` |
| Plan then implement autonomously | `plan-implement` | Continues only if root `PLAN.md` is actually `READY` |
| Existing `READY` plan + “implémente” | `implement` | Guarded by READY gate |
| Review current diff / PR | `review` / `pr-review` | Findings only |
| Verify claims / checks | `verify` | No editing |
| Destructive / secrets / prod / external write | `ops-stop` | Human checkpoint |
| CI red, explicit repair | `ci-fix` | Explicit consent for push |
| Linear ticket | `linear-work` / `linear-ticket-create` | MCP |
| Self-improvement from evidence | `plan-implement` + self-improvement skill | No auto-apply |

## Commands reference

### Claude Code

Main workflow commands (slash):

| Command | Purpose |
| --- | --- |
| `/plan` | Create `PLAN.md` only (stops at `DRAFT`) |
| `/plan-loop` | Create/review plan → `READY` or `CHALLENGED` |
| `/plan-implement` | Full autonomous chain: plan → adversary → implement → checks → archive |
| `/implement` | Implement an existing `READY` plan |
| `/adversary` | Stress-test `PLAN.md` before implementation |
| `/review` | Review current diff |
| `/verify-workflow` | Verify checks/claims without editing |
| `/pr-review` | Review a GitHub PR (`gh`) |
| `/pr-qa` | QA plan for a PR |
| `/sec-pr` | Dependabot / security PR audit |
| `/ci-fix` | Explicit autonomous CI repair |
| `/bug-check` | Analyze Linear bug root cause (no edit) |
| `/linear-ticket-create` | Create Linear ticket |
| `/linear-work` | Work from Linear ticket |
| `/ship` | A-to-Z delivery (explicit consent for branch + PR) |
| `/goal <condition>` | Long-running till-done loop with measurable stop |

Useful manual / recurring commands: `/pre-commit`, `/pr-feedback`, `/tests-iso`,
`/front-quality`, `/ui-debug`, `/recap`, `/adr`, `/spec-guide`.

Hooks (when `settings.workflow-hooks.json` is active):

- Router injects route context on prompt
- `plan-ready-guard` blocks writes while plan is not `READY`
- `plan-commit-guard` prevents committing root `PLAN*.md`

### Pi

| Skill | Purpose |
| --- | --- |
| `/skill:plan-loop <task>` | Create/review `PLAN.md` |
| `/skill:plan-implement <task>` | Plan then implement if `READY` |
| `/skill:adversary` | Adversarial plan review |
| `/skill:implement` | Implement existing `READY` plan |
| `/skill:review` | Review current diff |
| `/skill:verify` | Verify without editing |
| `/skill:pr-review` | GitHub PR review |
| `/skill:bug-check` | Linear bug analysis |
| `/skill:ci-fix` | Explicit CI repair |

See also `docs/pi-cheatsheet.md`.

## Typical daily scenarios

### Small safe fix
Just describe the change. The router usually picks a direct implement path
(or a very light plan). Focused checks + review before commit.

### Feature or non-trivial change
1. `/plan-loop` (or natural language “fais un plan pour …”)
2. Review / challenge until `READY`
3. `/implement` or continue with `/plan-implement`
4. Focused tests → review → archive → commit

### Autonomous end-to-end
`/plan-implement <task>` or `/goal <measurable condition + cap>`.
The run records the event ledger; final review should come from a fresh context.

### PR maintenance
Use the shared `pr-maintenance-loop` skill / contract: one PR, one worktree,
latest-head evidence via `scripts/pr-latest-head-status`, explicit cleanup.

### Self-improvement of the harness itself
Start from inspectable evidence (retrospect, failures, vNext, metrics),
classify candidates, implement only through a reviewed `READY` plan.
Never auto-apply retrospect output.

## Human checkpoints (do not skip)

- Destructive / secrets / production / billing / force-push → `ops-stop`
- External write-back (PR comments, Linear status, publish) → explicit command or `ops-stop`
- Premature implementation before `READY` → blocked by guards
- Missing validation surface → stop as blocked, do not claim completion

## Where to look next

| Need | Document |
| --- | --- |
| Full contract & routing table | `workflow/spec.md` |
| Graph / topology view | `workflow/topology.md` |
| Loop patterns | `workflow/loop-patterns.md` |
| Answer quality | `workflow/answer-quality.md` |
| Claude surface | `claude/README.md` |
| Pi surface | `docs/pi-cheatsheet.md` |
| Multi-model orchestration | `workflow/skills/multi-model-orchestration.md` |
| Deploy / install | `README.md` (Quick start + Deployment) |

## Validation of the harness itself

```bash
scripts/verify-agentic-infra core   # daily health
scripts/verify-agentic-infra full   # all deterministic checks
scripts/vnext-suite --json          # control-plane regression
```
