# Plan 002: Stop the router from downgrading work requests phrased as questions or mixed with analysis verbs

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts pi/extensions/__tests__/ tests/fixtures/claude-hooks/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Plan 001 MUST be DONE first (check
> `plans/README.md`).

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-router-parity-port.md
- **Category**: bug
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

Two confirmed misclassifications in the workflow router (both reproduced by executing the classifier):

1. `"peux-tu implémenter le fix du login ?"` → route `answer`. Any prompt ending in `?` is treated as a question because `QUESTION_PATTERN` contains a bare `\?\s*$` arm checked before every implementation branch. Politely-phrased work requests — extremely common in French chat — silently lose the plan/implement contract.
2. `"analyse et corrige le bug"` → `plan-implement`, but the synonym `"montre puis corrige le bug"` → `answer`. When a read-only verb (`montre`, `résume`, `explique`…) co-occurs with an action verb (`corrige`, `fix`…), the read-only branch wins because it is checked first, swallowing the fix request.

Both bugs cause silent under-routing: the agent answers instead of planning and implementing, and the workflow's evidence/stop-condition contract never activates. The fix is one precedence rule: a prompt containing a strong action verb is work, regardless of a trailing `?` or an accompanying read-only verb.

## Current state

Both classifiers have identical logic here (after plan 001). Claude side, `claude/hooks/workflow-router-lib.mjs`:

- Line 26-27 (patterns):

```js
const READ_ONLY_PATTERN = /\b(r[eé]sume|resume|summarize|explique|explain|lis|read|montre|show|d[eé]cris)\b/i;
const QUESTION_PATTERN = /^\s*(as[- ]?tu|a[- ]?t[- ]?on|as[- ]?ton|est[- ]?ce|qu['e]|quoi|pourquoi|comment|combien|quel|quelle|peux[- ]?tu m'expliquer|c'est quoi|y a[- ]?t[- ]?il)\b|\?\s*$/i;
```

- Line 233-235 (the branch, checked BEFORE all implement/plan branches at lines 237-313):

```js
if (READ_ONLY_PATTERN.test(prompt) || QUESTION_PATTERN.test(trimmed)) {
  return answerDecision("read-only, question, or summary request", "None", "answer delivered", "None");
}
```

- `IMPLEMENT_PATTERN` is at line 15 (broad action-verb list — after plan 001 it is identical in both files).

Pi side, `pi/extensions/lib/workflow-router-runtime.ts`: same patterns at lines 59-60, same branch at line 250-252 (line numbers may shift slightly after plan 001).

Existing Claude fixture corpus: `tests/fixtures/claude-hooks/router-*.json` (each is a hook-input JSON with a `prompt` field), exercised by `bash tests/claude-hooks-smoke.sh`. Example fixture: `tests/fixtures/claude-hooks/router-implement-verb.json`. The Pi/Claude parity test is `pi/extensions/__tests__/workflow-router-alignment.test.ts` (hardened by plan 001 to full-decision equality).

Behavior that must NOT change (regression guards — verify these still hold after your edit):

- `"Comment tester la PR GitHub 42 ?"` → `pr-qa` (PR branches are checked earlier; unaffected).
- `"Résume le PLAN.md ready"` → `answer` (read-only, no action verb).
- `"Résume le ticket Linear LIN-123"` → `answer` (Linear read branch, earlier).
- `"c'est quoi le rôle du challenger ?"` → `answer` (pure question, no action verb).
- `"explique comment fonctionne le hook"` → `answer` (read-only verb, no action verb).

Repo conventions: no comments in code; commit style `fix(scope): description`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Probe Claude classifier | `node -e 'import("./claude/hooks/workflow-router-lib.mjs").then(m => console.log(m.classifyWorkflowRoute(process.argv[1]).route))' "<prompt>"` | prints route |
| Probe Pi classifier | `cd pi && bun -e 'import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts"; console.log(classifyWorkflowRoute(process.argv[2] ?? "", {}).route)' -- "<prompt>"` | prints route |
| Parity + unit tests | `cd pi && bun test ./extensions/__tests__/*.test.ts` | all pass |
| Claude hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |
| Hook syntax | `node --check claude/hooks/workflow-router-lib.mjs` | exit 0 |

## Scope

**In scope**:
- `claude/hooks/workflow-router-lib.mjs`
- `pi/extensions/lib/workflow-router-runtime.ts`
- `pi/extensions/__tests__/workflow-router-alignment.test.ts` (add prompts)
- `tests/fixtures/claude-hooks/` (add fixtures) and, only if the smoke script requires registering new fixtures explicitly, `tests/claude-hooks-smoke.sh` — read it first to see how fixtures are discovered.

**Out of scope**:
- Any other pattern or branch in the classifiers (no opportunistic regex tuning).
- `workflow/spec.md`, command files, `claude/hooks/workflow-router.mjs` (entry), `pi/extensions/workflow-router.ts` (entry).

## Git workflow

- Branch: `advisor/002-router-question-precedence`
- Commit: `fix(workflow): route action-verb prompts to work even when phrased as questions`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Change the read-only/question branch in BOTH classifiers

Replace the branch condition so it yields to action verbs. In `claude/hooks/workflow-router-lib.mjs:233`:

```js
if ((READ_ONLY_PATTERN.test(prompt) || QUESTION_PATTERN.test(trimmed)) && !IMPLEMENT_PATTERN.test(prompt)) {
```

Apply the character-identical change to the Pi branch in `pi/extensions/lib/workflow-router-runtime.ts` (same condition, same pattern names).

Rationale for this exact shape (rather than reordering branches): the read-only branch keeps winning for genuine questions and summaries; prompts containing any strong action verb fall through to the implement/plan branches below. `"comment tester la PR 42 ?"` is unaffected (routed earlier by `pr-qa`); `"peux-tu m'expliquer..."` stays `answer` (no action verb).

**Verify** (each probe on BOTH classifiers):
- `"peux-tu implémenter le fix du login ?"` → `plan-implement`
- `"montre puis corrige le bug"` → `plan-implement`
- `"analyse et corrige le bug"` → `plan-implement` (unchanged)
- `"c'est quoi le rôle du challenger ?"` → `answer`
- `"explique comment fonctionne le hook"` → `answer`
- `"Résume le PLAN.md ready"` → `answer`

### Step 2: Add parity-test prompts

In `pi/extensions/__tests__/workflow-router-alignment.test.ts`, add to the prompt list:
- `"peux-tu implémenter le fix du login ?"`
- `"montre puis corrige le bug"`
- `"explique comment fonctionne le hook"`
- `"c'est quoi le rôle du challenger ?"`

**Verify**: `cd pi && bun test ./extensions/__tests__/workflow-router-alignment.test.ts` → all pass.

### Step 3: Add Claude-side fixtures

Read `tests/claude-hooks-smoke.sh` to learn how `tests/fixtures/claude-hooks/router-*.json` fixtures are consumed and what each asserts (route expectations may live in the script or alongside the fixture). Then add two fixtures modeled on `tests/fixtures/claude-hooks/router-implement-verb.json`:
- `router-question-implement.json` with prompt `"peux-tu implémenter le fix du login ?"` asserting route `plan-implement`.
- `router-read-then-fix.json` with prompt `"montre puis corrige le bug"` asserting route `plan-implement`.

If the smoke script has no per-fixture route assertion mechanism, add the assertions the same way the existing router fixtures are asserted — mirror the existing mechanism exactly; do not invent a new one.

**Verify**: `bash tests/claude-hooks-smoke.sh` → exit 0.

### Step 4: Full regression

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass; `node --check claude/hooks/workflow-router-lib.mjs` → exit 0.

## Test plan

- New parity prompts (step 2) and Claude fixtures (step 3) cover: question-phrased implement, read-then-fix, pure question, pure read-only.
- Regression guards from "Current state" are executed as probes in step 1; the four that map to existing fixtures/tests stay green.
- Pattern: existing alignment test structure; existing fixture JSON shape.

## Done criteria

- [ ] Both probe matrices in step 1 print the expected routes (record the exact commands + output)
- [ ] `cd pi && bun test ./extensions/__tests__/*.test.ts` exits 0
- [ ] `bash tests/claude-hooks-smoke.sh` exits 0
- [ ] The condition `&& !IMPLEMENT_PATTERN.test(prompt)` appears in both classifiers (`grep -c 'IMPLEMENT_PATTERN.test(prompt)' claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts` — count increases by exactly 1 in each vs baseline)
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 001 is not DONE (the hardened parity test is this plan's safety net).
- Any regression-guard probe from "Current state" changes route after your edit.
- `tests/claude-hooks-smoke.sh` asserts fixture routes through a mechanism you cannot extend without modifying unrelated assertions.
- You find additional prompts that flip route due to this change and cannot decide whether the new route is correct — list them with before/after routes and stop.

## Maintenance notes

- This encodes a precedence rule: action verb beats question mark and read-only verb. If a future route needs the opposite (e.g. a "explain how to fix" tutorial route), revisit the guard rather than adding regex exceptions.
- Reviewer: check the change is character-identical in both classifiers and that no other branch was touched.
