# Plan 010: Minor debt — remove the near-dead PROMPT_ARTIFACT route inconsistency and cache the tasks-till-done archive scan

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts pi/extensions/tasks-till-done.ts pi/extensions/__tests__/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Plans 001 and 002 shift line
> numbers in the classifiers — locate by symbol, not line.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-router-parity-port.md (hardened parity test must exist first)
- **Category**: tech-debt
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

Two small, contained cleanups. (1) The `PROMPT_ARTIFACT_PATTERN` branch is the only classifier branch that tests against `normalized` text while every other branch tests raw `prompt` — a maintenance trap where normalization changes silently affect exactly one route; it is also nearly unreachable (it requires `prompt`/`goal` wording that misses ALL earlier branches). Making it match raw `prompt` like its 30 siblings removes the inconsistency without deleting the route (deletion needs prompt-corpus evidence nobody has collected). (2) `tasks-till-done` re-scans `docs/plan/` with `readdirSync` + per-file `statSync` on every `agent_end` of an implement loop (up to 12 continues) even after the archive has been found — a one-line latch caches the positive result.

## Current state

### PROMPT_ARTIFACT branch

- `claude/hooks/workflow-router-lib.mjs:19`: `const PROMPT_ARTIFACT_PATTERN = /\b(prompt|goal)\b/i;` and line 315:

```js
  if (PROMPT_ARTIFACT_PATTERN.test(normalized)) {
    return answerDecision("prompt artifact request", "prompt artifact", "prompt delivered", "User-facing prompt text");
  }
```

- `pi/extensions/lib/workflow-router-runtime.ts:61` and `:318`: identical shape (`PROMPT_ARTIFACT_PATTERN.test(normalized)`).
- `normalized` = `normalizePrompt(prompt)` (NFKD, diacritics stripped, lowercased). For the ASCII case-insensitive words `prompt|goal`, testing `normalized` vs raw `prompt` differs only on exotic Unicode spellings — the switch is behavior-preserving for any realistic input.

### tasks-till-done archive scan

- `pi/extensions/tasks-till-done.ts:44-53`:

```ts
function hasImplementedPlanArchive(cwd: string, startedAtMs: number): boolean {
  try {
    return readdirSync(join(cwd, "docs", "plan")).some((name) => {
      ...
      return statSync(join(cwd, "docs", "plan", name)).mtimeMs >= startedAtMs - 1000;
```

- Called from `getImplementationRuntimeEvidence` (`:55-60`), invoked on every `agent_end` (`:133-136`) while `implementationCompletionRequired` is true. Once it returns true it can never meaningfully become false again within the same loop (the archive file has been written); re-scanning is pure waste.
- State variables live in the extension closure (`:62-75`); loop state is reset in `before_agent_start` when the prompt is not an extension continuation (`:79-95`).

Tests: `cd pi && bun test ./extensions/__tests__/*.test.ts` (there is a tasks-till-done test file — check `ls pi/extensions/__tests__`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Pi suite | `cd pi && bun test ./extensions/__tests__/*.test.ts` | all pass |
| Hook syntax | `node --check claude/hooks/workflow-router-lib.mjs` | exit 0 |
| Hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |

## Scope

**In scope**:
- `claude/hooks/workflow-router-lib.mjs` (one-token change: `normalized` → `prompt` in the PROMPT_ARTIFACT branch)
- `pi/extensions/lib/workflow-router-runtime.ts` (same)
- `pi/extensions/tasks-till-done.ts` (archive latch)
- `pi/extensions/__tests__/` (one test for the latch if the existing suite structure supports it cheaply)

**Out of scope**:
- Deleting the PROMPT_ARTIFACT route (needs usage evidence; recorded as deferred).
- `normalizePrompt` itself and every other classifier branch.
- `pi/extensions/lib/tasks-till-done-runtime.ts` (pure decision logic — untouched).

## Git workflow

- Branch: `advisor/010-minor-debt`
- Commit: `refactor(workflow): align prompt-artifact matching and latch archive scan`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Align PROMPT_ARTIFACT matching in both classifiers

Change `PROMPT_ARTIFACT_PATTERN.test(normalized)` to `PROMPT_ARTIFACT_PATTERN.test(prompt)` in both files (locate by the `PROMPT_ARTIFACT_PATTERN.test` call, not by line number). If this leaves `normalized` unused in either file, remove the `const normalized = ...` line in that file only (check with grep first: `grep -n "normalized" <file>`).

**Verify**: `node --check claude/hooks/workflow-router-lib.mjs` → exit 0; `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass; probe both classifiers with `"écris-moi un prompt pour un agent"` → same route on both (expected `plan-implement` because `écris` is a create/implement verb — record whatever it is, the point is parity, and note it went through earlier branches, proving the artifact branch's low reachability).

### Step 2: Latch the archive scan in tasks-till-done

In `pi/extensions/tasks-till-done.ts`:
- Add closure state `let archiveSeen = false;` next to the other loop state (`:62-75`).
- Reset it to `false` in the `before_agent_start` non-continuation reset block (`:81-95`).
- In `getImplementationRuntimeEvidence` usage, short-circuit: compute `archiveSeen = archiveSeen || hasImplementedPlanArchive(currentCwd, taskLoopStartedAtMs)` and pass `archiveSeen` as the `hasImplementedPlanArchive` evidence value (keep the `rootPlanDeleted` check live every time — PLAN.md deletion genuinely toggles late).

The function signature of `getImplementationRuntimeEvidence` may need the latch passed in or the logic inlined at the call site (`:133-136`) — choose whichever keeps the smallest diff; do not restructure the file.

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass.

### Step 3: Add a latch test if cheap

Read the tasks-till-done test file. If it already fakes `agent_end` cycles with a temp `docs/plan/`, add a case: archive created once → evidence stays true on subsequent `agent_end` even after the archive file is deleted mid-loop (proving the latch, which is the intended semantic: "was written during this loop"). If the test harness cannot simulate this without significant scaffolding, skip and note it.

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass.

## Test plan

- Existing Pi suite green throughout (parity test from plan 001 guards step 1).
- Optional latch test per step 3.

## Done criteria

- [ ] `grep -c "PROMPT_ARTIFACT_PATTERN.test(prompt)" claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts` → 1 each; `test(normalized)` gone
- [ ] `cd pi && bun test ./extensions/__tests__/*.test.ts` exits 0
- [ ] `bash tests/claude-hooks-smoke.sh` exits 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Probing shows the `normalized`→`prompt` switch changes the route of ANY prompt in the alignment-test corpus or the Claude fixtures — report the prompt (means an earlier branch depends on the artifact branch's normalization, which contradicts the analysis).
- The tasks-till-done closure state is not where "Current state" says (file restructured since `1f89823`).

## Maintenance notes

- Deferred deliberately: deleting the PROMPT_ARTIFACT route outright. If a future prompt-corpus audit shows zero hits, delete the branch in both files plus its `answerDecision` reason string.
- The latch encodes "archive was written at some point during this loop"; if the workflow ever requires the archive to still exist at loop end, remove the latch and re-scan.
