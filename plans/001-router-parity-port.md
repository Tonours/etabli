# Plan 001: Restore Pi/Claude router parity and make the alignment test catch full-decision drift

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts pi/extensions/__tests__/workflow-router-alignment.test.ts`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

This repo ships the same prompt-routing logic twice: a Node hook for Claude Code (`claude/hooks/workflow-router-lib.mjs`) and a Bun extension for Pi (`pi/extensions/lib/workflow-router-runtime.ts`). They must classify identical prompts identically — `workflow/spec.md` calls them "thin runtime adapters over this contract". They have already drifted: the Claude side gained a whole `spec-guide` route and richer `IMPLEMENT_PATTERN`/`OPS_STOP_PATTERN`/`CI_FIX_PATTERN` regexes that were never ported to Pi. Verified by running both classifiers: `"rédige une nouvelle spec"` routes to `spec-guide` on Claude and `plan-loop` on Pi. The alignment test exists precisely to catch this but stayed green because its 19 prompts contain no spec prompt and it only asserts `route` + `writeAllowed`. This plan ports the divergence and hardens the test so future drift fails CI.

## Current state

- `claude/hooks/workflow-router-lib.mjs` — Claude classifier (canonical richer version, 452 lines). Exports `classifyWorkflowRoute(prompt, context)`.
- `pi/extensions/lib/workflow-router-runtime.ts` — Pi classifier (stale version, 392 lines). Exports `classifyWorkflowRoute(prompt, context)` and the `WorkflowRoute` union type.
- `pi/extensions/__tests__/workflow-router-alignment.test.ts` — the parity test. It already imports BOTH implementations (the `.mjs` via `await import("../../../claude/hooks/workflow-router-lib.mjs")` at line 17), so cross-importing works under Bun.

Known divergences (Claude = source of truth for all of them):

1. **`spec-guide` route missing on Pi.** Claude has, at `claude/hooks/workflow-router-lib.mjs:12-14`:

```js
const SPEC_GUIDE_PATTERN = /(spec-guide|guide[- ]?moi|aide[- ]?moi[\s\S]{0,20}sp[eé]c|construis[\s\S]{0,20}sp[eé]c|extraire[\s\S]{0,20}sp[eé]c|pose[- ]?moi les questions|interroge[- ]?moi)/iu;
const SPEC_INTENT_PATTERN = /(sp[eé]c|spec)\b/iu;
const SPEC_CREATE_VERB_PATTERN = /(cr[eé]e|cr[eé]er|nouvelle|r[eé]dige|write|[eé]cri[ts]|construis|drafte?)/iu;
```

and the branch at `claude/hooks/workflow-router-lib.mjs:289-300`, placed AFTER the `IMPLEMENT_PATTERN` branch and BEFORE the plain `PLAN_PATTERN` branch:

```js
if (SPEC_GUIDE_PATTERN.test(prompt) || (SPEC_INTENT_PATTERN.test(prompt) && SPEC_CREATE_VERB_PATTERN.test(prompt) && !PR_CONTEXT_PATTERN.test(prompt) && !LINEAR_PATTERN.test(prompt))) {
  return {
    route: "spec-guide",
    reason: "spec construction request — build it by guided interview before formatting",
    command: "/spec-guide",
    ...
```

`pi/extensions/lib/workflow-router-runtime.ts` has none of these patterns, no branch, and no `"spec-guide"` member in the `WorkflowRoute` union (lines 3-19).

2. **`IMPLEMENT_PATTERN` diverged.** Claude (`workflow-router-lib.mjs:15`) matches many more action verbs (`maj`, `nettoie`, `renomme`, `active`, `désactive`, `mets en place`, `optimise`, `supprime`, `delete`, `remove`, `retire`, …). Pi (`workflow-router-runtime.ts:55`) still has the short list:

```ts
const IMPLEMENT_PATTERN = /\b(impl[eé]mente|implemente|implement|code|build|corrige|fix|r[eé]pare|ajoute|modifie|update|cleanup|remplace)\b/i;
```

3. **`OPS_STOP_PATTERN` diverged.** Claude (`workflow-router-lib.mjs:20`) scopes destructive verbs to targets (`(supprime|remove|delete|efface)\s+(this|ce|le…)?(folder|dossier|repo|…)`) and adds `git push`, `truncate`, `delete from`, `drop table`. Pi (`workflow-router-runtime.ts:62`) is the loose old pattern where bare `supprime`, `push`, or `deploy` anywhere triggers `ops-stop`:

```ts
const OPS_STOP_PATTERN = /\b(supprime|delete|remove|rm -rf|prod|production|secret|credential|billing|deploy|push|force[- ]?push|migration destructive)\b/i;
```

4. **`CI_FIX_PATTERN` and `REVIEW_PATTERN` slightly diverged.** Claude `CI_FIX_PATTERN` (`:33`) accepts `fix\s+(la\s+)?ci|corrige\s+(la\s+)?ci|r[eé]pare\s+(la\s+)?ci`; Pi (`:73`) only `fix ci|corrige la ci`. Claude `REVIEW_PATTERN` (`:6`) includes `review(?:er|ing)?`; Pi (`:49`) only `review`.

5. **The alignment test is too weak** (`pi/extensions/__tests__/workflow-router-alignment.test.ts:48-56`): for its 19 prompts it asserts only:

```ts
expect(equivalentRoute(claudeDecision.route)).toBe(piDecision.route);
expect(claudeDecision.writeAllowed).toBe(piDecision.writeAllowed);
```

`stopCondition`/`requiredEvidence`/`planChain` are compared on only 2 hand-picked prompts (lines 71-95). Note: intentional per-adapter differences exist and must NOT be asserted equal — Claude uses `command: "/x"` where Pi uses `skill: "x"`, Claude route `verify-workflow` maps to Pi `verify` (the test's `equivalentRoute()` helper handles this), and some `stopCondition` strings differ by a `Verdict: ` prefix (Claude `"Verdict: GO, ..."` vs Pi `"GO, ..."` — see `workflow-router-lib.mjs:127` vs `workflow-router-runtime.ts:145`).

Repo conventions: TypeScript strict, no `any`, no comments in code (existing block comments in the test file at lines 58-60 and 68-70 are the local exception pattern for test intent — you may follow it). Commit style `type(scope): description`, e.g. `fix(pi): stabilize install bootstrap` from git log.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Pi TS tests | `cd pi && bun test ./extensions/__tests__/workflow-router-alignment.test.ts` | all pass, exit 0 |
| Full Pi suite | `cd pi && bun test ./extensions/__tests__/*.test.ts` | all pass, exit 0 |
| Claude hook syntax | `node --check claude/hooks/workflow-router-lib.mjs` | exit 0, no output |
| Claude hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |
| Quick manual probe | `node -e 'import("./claude/hooks/workflow-router-lib.mjs").then(m => console.log(m.classifyWorkflowRoute("rédige une nouvelle spec").route))'` | `spec-guide` |

## Scope

**In scope** (the only files you should modify):
- `pi/extensions/lib/workflow-router-runtime.ts`
- `pi/extensions/__tests__/workflow-router-alignment.test.ts`

**Out of scope** (do NOT touch, even though they look related):
- `claude/hooks/workflow-router-lib.mjs` — it is the source of truth in this plan; changing it invalidates the port. Routing behavior changes to BOTH files are plan 002's job.
- `workflow/spec.md`, `claude/CLAUDE.md` — documenting `spec-guide` is plan 005.
- `pi/extensions/workflow-router.ts` (the adapter entry) — no change needed; it calls `classifyWorkflowRoute` generically.
- `tests/fixtures/claude-hooks/*` — Claude-side fixtures unchanged.

## Git workflow

- Branch: `advisor/001-router-parity-port`
- One commit per step or one squashed commit: `fix(pi): port spec-guide route and pattern parity from claude router` and `test(pi): assert full router decision parity`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Port the diverged patterns into `workflow-router-runtime.ts`

In `pi/extensions/lib/workflow-router-runtime.ts`:
- Replace `IMPLEMENT_PATTERN` (line 55), `OPS_STOP_PATTERN` (line 62), `CI_FIX_PATTERN` (line 73), and `REVIEW_PATTERN` (line 49) with the exact regex bodies from `claude/hooks/workflow-router-lib.mjs` lines 15, 20, 33, and 6 respectively (copy character-for-character).
- Add the three spec patterns (`SPEC_GUIDE_PATTERN`, `SPEC_INTENT_PATTERN`, `SPEC_CREATE_VERB_PATTERN`) copied from `workflow-router-lib.mjs:12-14`.

**Verify**: `cd pi && bun test ./extensions/__tests__/workflow-router-alignment.test.ts` → still passes (existing prompts must not regress).

### Step 2: Add the `spec-guide` route to Pi

- Add `"spec-guide"` to the `WorkflowRoute` union (line 3-19).
- Insert the `spec-guide` branch in `classifyWorkflowRoute` at the same position as Claude: after the final `IMPLEMENT_PATTERN` branch (Pi line 293-304), before the plain `PLAN_PATTERN` branch (Pi line 306). Mirror the Claude decision object from `workflow-router-lib.mjs:289-300` but use the Pi shape: `skill: "spec-guide"` instead of `command: "/spec-guide"`, and no `suggestion` field unless you also add `suggestion?: string` to `WorkflowRouteDecision` — Claude's decision carries `suggestion` (`workflow-router-lib.mjs:298`); add the optional field to the Pi type and include the same string so the decisions stay comparable.

**Verify**: `cd pi && bun -e 'import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts"; console.log(classifyWorkflowRoute("rédige une nouvelle spec", {}).route)'` → `spec-guide`

### Step 3: Harden the alignment test

In `pi/extensions/__tests__/workflow-router-alignment.test.ts`:

1. Extend the `prompts` array (lines 26-46) with at least these divergence-sensitive prompts:
   - `"rédige une nouvelle spec"` (spec-guide)
   - `"guide-moi pour construire la spec"` (spec-guide)
   - `"mets à jour la doc du router"` (implement verbs)
   - `"renomme la fonction classify"` (implement verbs)
   - `"deploy staging"` (ops-stop)
   - `"supprime ce dossier"` (ops-stop, scoped form)
   - `"corrige la ci"` (ci-fix)
2. Replace the per-prompt assertion body with a normalized full-decision comparison:

```ts
function normalize(decision: { route: string; stopCondition: string; requiredEvidence: string; writeAllowed: boolean; planChain?: unknown }) {
  return {
    route: equivalentRoute(decision.route),
    stopCondition: decision.stopCondition.replace(/Verdict: /g, ""),
    requiredEvidence: decision.requiredEvidence,
    writeAllowed: decision.writeAllowed,
    planChain: decision.planChain ?? null,
  };
}
```

and assert `expect(normalize(claudeDecision)).toEqual(normalize(piDecision))` for every prompt in the list. Keep the two existing dedicated tests (READY gate, plan-chain metadata) unchanged.

**Verify**: `cd pi && bun test ./extensions/__tests__/workflow-router-alignment.test.ts` → all pass, count increased by ≥7 tests.

### Step 4: Full regression

**Verify**:
- `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass
- `node --check claude/hooks/workflow-router-lib.mjs` → exit 0
- `bash tests/claude-hooks-smoke.sh` → exit 0

## Test plan

- The hardened alignment test IS the test deliverable: ≥7 new parity prompts + full-decision normalized equality on every prompt.
- Pattern to follow: the existing structure of `workflow-router-alignment.test.ts` (bun:test, `describe`/`test`, cross-import of the `.mjs`).
- Cases covered: spec-guide (both trigger forms), broadened implement verbs, scoped vs bare ops-stop wording, ci-fix French forms.

## Done criteria

- [ ] `cd pi && bun test ./extensions/__tests__/*.test.ts` exits 0
- [ ] `bash tests/claude-hooks-smoke.sh` exits 0
- [ ] `cd pi && bun -e 'import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts"; console.log(classifyWorkflowRoute("rédige une nouvelle spec", {}).route)'` prints `spec-guide`
- [ ] `grep -c "spec-guide" pi/extensions/lib/workflow-router-runtime.ts` ≥ 2
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts above don't match the live code (drift since `1f89823`).
- After porting, the normalized full-decision comparison reveals ADDITIONAL intentional divergences beyond `command`/`skill`, `verify-workflow`/`verify`, and the `Verdict: ` prefix — list them and ask which side is canonical instead of forcing equality.
- Any pre-existing test in `pi/extensions/__tests__/` fails before you make changes (broken baseline).

## Maintenance notes

- This plan makes drift *detectable*, not impossible: any future routing change must still be applied to both files. Plan 010 records the possible follow-up of physically sharing one module; rejected for now (the `.mjs`/`.ts` dual-runtime import works in tests but is unproven for the deployed `~/.pi` symlink layout).
- Reviewer should diff the two pattern sets side by side and confirm character-identical regex bodies.
- Plan 002 (question/action precedence) builds on the hardened test and edits BOTH classifiers; land 001 first.
