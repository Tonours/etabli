# Plan 016: Formal human-checkpoint taxonomy — every stop category named, mapped to its enforcement surface, and tested where enforceable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- workflow/spec.md claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts claude/commands/ tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Plans 001/002 shift classifier line
> numbers — locate by symbol. If plan 011 (agent scenarios) is DONE, add the
> new fixtures there instead of `tests/fixtures/claude-hooks/` (step 3 notes
> both paths).

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-router-parity-port.md, plans/002-router-question-action-precedence.md
- **Category**: docs
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

"When must the agent stop and ask a human" is the single highest-stakes rule in this workflow system, and today it exists as: one regex (`OPS_STOP_PATTERN`), one routing-table row, and scattered prose (CLAUDE.md safety bullets, command-level HITL contracts like `/pr-review`'s validated posting). Nobody can answer "which stop categories exist, and what enforces each one?" without reading five files. The gaps hide there: at `1f89823`, *external write-backs* (posting a Linear comment, submitting a PR review, updating an issue status) are guarded only inside individual command contracts — a prompt like "poste un commentaire sur la PR" routes through generic classification with no checkpoint semantics; *ambiguous target* ("clean up the repo" — which repo?) and *missing validation surface* (no test/check exists to prove the change) have no named rule at all, so each agent improvises. This plan writes the taxonomy once in `workflow/spec.md`, maps every category to its enforcement surface (router pattern / hook guard / command contract / prose rule), closes the one router-enforceable gap worth closing, and pins each router-enforceable category with a fixture. The categories come from the maintainer's research handoff, grounded in the plan-then-execute literature: checkpoints sit at phase boundaries and irreversibility boundaries, not on every step.

## Current state

- Router enforcement — `claude/hooks/workflow-router-lib.mjs:20` (Claude; Pi equivalent aligned by plan 001):

```js
const OPS_STOP_PATTERN = /(rm\s+-rf|force[- ]?push|push\s+(en\s+)?force|push\s+--force|git\s+push|\bprod(uction)?\b|\bdeploy(er|ment)?\b|\bbilling\b|migration\s+destructive|drop\s+(table|database|la\s+table|la\s+base)|truncate\s+|delete\s+from|\bsecret(s|e)?\b|\bcredential|(supprime|remove|delete|efface)\s+(this\s+|ce\s+|le\s+|la\s+|the\s+)?(folder|dossier|directory|r[eé]pertoire|repo|database|base|branch|branche))/i;
```

  and the `ops-stop` branch (`:85-95`): route `ops-stop`, artifact "risk brief", stop "user decision before risky action", `writeAllowed: false`. Checked SECOND (after ci-fix) — ci-fix deliberately outranks it for explicit CI-repair pushes.
- Hook guard enforcement — `plan-ready-guardDecision` (`workflow-router-lib.mjs:397-415`): blocks writes/mutating bash while PLAN.md is DRAFT/CHALLENGED.
- Routing-table row — `workflow/spec.md:122`: `| Destructive, secret, production, billing, deployment, or broad irreversible work | ops-stop | risk brief | user decision |`.
- Prose — `claude/CLAUDE.md` Safety section ("Treat secrets, credentials, production data, destructive commands, and external side effects as explicit approval points") and Workflow ops-stop bullet; command-level HITL: `claude/commands/pr-review.md` (posting requires validation phase), `claude/commands/sec-pr.md` (never auto-merge), `claude/commands/linear-ticket-create.md` (external write is the command's explicit purpose — consented by invocation).
- Handoff's category list: deletion/destructive, production write, external comment/status update, force push/history rewrite, ambiguity repo/target, missing validation surface, secrets/security-sensitive.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Probe Claude | `node -e 'import("./claude/hooks/workflow-router-lib.mjs").then(m => console.log(m.classifyWorkflowRoute(process.argv[1]).route))' "<prompt>"` | route |
| Probe Pi | `cd pi && bun -e 'import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts"; console.log(classifyWorkflowRoute(process.argv[2] ?? "", {}).route)' -- "<prompt>"` | route |
| Parity tests | `cd pi && bun test ./extensions/__tests__/*.test.ts` | all pass |
| Hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |
| Docs smoke | `bash tests/workflow-docs-smoke.sh` | exit 0 |

## Scope

**In scope**:
- `workflow/spec.md` (new "Human checkpoints" section)
- `claude/hooks/workflow-router-lib.mjs` + `pi/extensions/lib/workflow-router-runtime.ts` (ONE bounded pattern addition, step 2 — both files, character-identical)
- `pi/extensions/__tests__/workflow-router-alignment.test.ts` (parity prompts)
- `tests/fixtures/claude-hooks/` + `tests/claude-hooks-smoke.sh` (fixtures) — or `tests/agent-scenarios/` if plan 011 landed
- `claude/CLAUDE.md` Safety section (one pointer line)

**Out of scope**:
- Enforcing `ambiguity` and `missing-validation-surface` in code — they are judgment categories; the deliverable for them is the named prose rule, not a regex (a regex for "ambiguous" is a false-positive machine).
- Command files' own HITL contracts (`pr-review.md`, `sec-pr.md`, …) — referenced by the taxonomy, not edited.
- Runtime enforcement beyond routing (e.g. a PreToolUse hook blocking `gh pr comment`) — a future decision once the taxonomy exists; note it, don't build it.

## Git workflow

- Branch: `advisor/016-checkpoint-taxonomy`
- Commits: `docs(workflow): formalize human-checkpoint taxonomy` then `fix(workflow): route external write-back prompts to ops-stop`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Write the taxonomy in `workflow/spec.md`

New section "## Human checkpoints" after "Routing rules", one table:

| Category | Examples | Enforcement | Behavior |
|----------|----------|-------------|----------|
| deletion / destructive | rm -rf, drop/truncate, delete repo/branch | router `OPS_STOP_PATTERN` (both adapters) | route `ops-stop`, risk brief, wait |
| production / billing write | deploy, prod config, billing | router `OPS_STOP_PATTERN` | route `ops-stop` |
| history rewrite / push | force-push, git push, rebase published | router `OPS_STOP_PATTERN`; explicit `/ci-fix` is the consented exception (pattern checked first) | route `ops-stop` unless explicit ci-fix |
| secrets / credentials | reading, writing, printing secrets | router `OPS_STOP_PATTERN` + `filter-output` extension (Pi) + sensitive-file blocks | route `ops-stop`; output redaction |
| external write-back | post PR review/comment, update Linear status, publish | command-level HITL contracts (`/pr-review` validated posting, `/sec-pr` no auto-merge, `/linear-*` MCP evidence); router addition in step 2 for bare prompts | command contract or `ops-stop` |
| premature implementation | any write before PLAN.md READY | `plan-ready-guard` hook (Claude), READY gate rule (all) | tool call denied |
| ambiguous target | "clean up the repo" with several candidates | prose rule (this section): agent must name the resolved target and get confirmation when ≥2 plausible targets exist | ask, do not guess |
| missing validation surface | change with no runnable check | prose rule: stop condition "blocked: no validation surface" instead of claiming completion | report blocked |

Plus 3 lines of doctrine: checkpoints sit at irreversibility boundaries, not every step; a checkpoint consumed by explicit user invocation (e.g. `/linear-ticket-create`) is consent; journal checkpoint decisions as `human_checkpoint` events when a run ledger exists (`workflow/events.md`, plan 012 — reference only if landed, else cite the plan).

**Verify**: `bash tests/workflow-docs-smoke.sh` → exit 0 (reconcile spec-shape assertions minimally if needed; other failures → STOP).

### Step 2: Close the router-enforceable external-write-back gap

Add to BOTH classifiers, character-identical, a pattern for bare external write-back prompts and OR it into the existing ops-stop branch condition (do NOT create a new route):

```js
const EXTERNAL_WRITE_BACK_PATTERN = /\b(poste?|publie|post|publish|submit|soumets?)\b[\s\S]{0,40}\b(comment(aire)?s?|review|status|r[eé]ponse)\b|\bapprove\s+(the\s+|la\s+)?pr\b/i;
```

Branch condition becomes `if (OPS_STOP_PATTERN.test(prompt) || EXTERNAL_WRITE_BACK_PATTERN.test(prompt))`. Placement note: the Linear/PR command branches (`sec-pr`, `pr-qa`, `pr-review`, `linear-*`) are checked AFTER ops-stop — verify with probes that legitimate command-shaped prompts still reach their commands: `"Fais une code review de la PR GitHub 42"` must stay `pr-review` (it contains neither posting verb — confirm), and `"Peux-tu créer un ticket Linear pour corriger le bug de login"` must stay `linear-ticket-create` (no posting verb — confirm). If any regression-guard prompt from the plan-001/002 corpus flips, STOP and report; the pattern needs narrowing, and the fallback deliverable is taxonomy-without-pattern (step 2 dropped, table row says "command contracts only").

**Verify** (both classifiers):
- `"poste un commentaire sur la PR 42"` → `ops-stop`
- `"publie la review sur GitHub"` → `ops-stop`
- `"approve the PR"` → `ops-stop`
- `"Fais une code review de la PR GitHub 42"` → `pr-review` (unchanged)
- `"Audite la PR Dependabot #1606"` → `sec-pr` (unchanged)
- full corpus: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass

### Step 3: Pin with fixtures and parity prompts

- Add the three new ops-stop prompts + the two unchanged guards to `pi/extensions/__tests__/workflow-router-alignment.test.ts`.
- Add Claude fixtures `router-external-writeback.json` (poste un commentaire → ops-stop) and `router-review-still-routes.json` (code review PR 42 → pr-review) following the existing fixture/assertion mechanism in `tests/claude-hooks-smoke.sh` — or, if plan 011 landed, as two `tests/agent-scenarios/` directories instead.

**Verify**: `bash tests/claude-hooks-smoke.sh` (and/or `bash tests/agent-scenarios-smoke.sh`) → exit 0.

### Step 4: Pointer from CLAUDE.md

In `claude/CLAUDE.md` Safety section, append one line: "Checkpoint taxonomy and enforcement map: `workflow/spec.md` → Human checkpoints."

**Verify**: `bash tests/workflow-docs-smoke.sh` → exit 0.

## Test plan

- Step 2's probe matrix (5 prompts × 2 classifiers) recorded in the report.
- Parity prompts + fixtures from step 3.
- Existing corpus green throughout (plans 001/002's hardened tests are the net — hence the dependency).

## Done criteria

- [ ] spec.md "Human checkpoints" table: 8 categories, each with enforcement surface
- [ ] `EXTERNAL_WRITE_BACK_PATTERN` identical in both classifiers; probe matrix passes (or step-2 fallback taken and documented)
- [ ] `cd pi && bun test ./extensions/__tests__/*.test.ts` exits 0
- [ ] `bash tests/claude-hooks-smoke.sh` exits 0
- [ ] `bash tests/workflow-docs-smoke.sh` exits 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Plans 001/002 not DONE (no parity net; classifier line drift unresolved).
- Any existing-corpus prompt changes route because of the new pattern — narrow or drop the pattern (fallback documented in step 2); never ship a checkpoint pattern that swallows legitimate command routes.
- The taxonomy forces a category the router table can't express (e.g. a new route seems needed) — that is a contract change for the maintainer, not this plan.

## Maintenance notes

- The taxonomy is now the checklist for reviewing any new command: which checkpoint categories does it touch, and which surface enforces each?
- The two prose-only categories (ambiguous target, missing validation surface) are candidates for enforcement if violations recur — evidence would be `human_checkpoint`/`blocked` events in run ledgers (plan 012).
- A PreToolUse hook denying `gh pr comment`/`gh pr review --approve` outside `/pr-review` is the logical hardening step if the router pattern proves insufficient; deliberately not built here.
