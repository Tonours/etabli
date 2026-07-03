# Plan 006: Short-circuit the ADR Stop hook so turns without decision signals do zero subprocess and transcript work

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- claude/hooks/detect-adr-signal.mjs tests/adr-hook-smoke.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

`claude/hooks/detect-adr-signal.mjs` runs as a `Stop` hook on EVERY turn end (wired in `claude/settings.workflow-hooks.json`, `Stop` entry, 5s timeout). Its current evaluation order does the expensive work first: `adrAlreadyTouched` and `hasStructuralChange` each spawn a `git status --porcelain --untracked-files=all` subprocess, and only then does `hasDecisionSignal` run — which itself falls back to reading and JSON-parsing the ENTIRE session transcript line by line, a cost that grows without bound over a long session. Most turns contain no decision marker, so most of this work is wasted. Reordering to cheapest-first (text signal → git) and reading the transcript backwards only when needed makes the common case near-free. The hook is advisory-only (it emits a `systemMessage` suggestion), so the change cannot break workflow behavior — only the suggestion's presence matters, and that is already covered by smoke tests.

## Current state

`claude/hooks/detect-adr-signal.mjs` (110 lines total):

- Lines 35-52 — `porcelainPaths(cwd, pathspec)`: spawns `git status --porcelain --untracked-files=all` via `execFileSync`.
- Lines 54-60 — `hasStructuralChange(cwd)` (git call #1) and `adrAlreadyTouched(cwd)` (git call #2, with `docs/adr` pathspec).
- Lines 62-89 — `lastAssistantFromTranscript(transcriptPath)`: `readFileSync` of the whole transcript, splits ALL lines, then iterates from the end JSON-parsing each line until it finds an assistant entry.
- Lines 91-96 — `hasDecisionSignal(input)`: prefers `input.last_assistant_message` when present, else falls back to the transcript read:

```js
function hasDecisionSignal(input) {
  const primary = typeof input.last_assistant_message === "string" ? input.last_assistant_message : "";
  const text = (primary || lastAssistantFromTranscript(input.transcript_path)).toLowerCase();
  ...
```

- Lines 101-105 — current evaluation order:

```js
if (
  !adrAlreadyTouched(cwd) &&
  hasStructuralChange(cwd) &&
  hasDecisionSignal(input)
) {
```

Existing tests: `bash tests/adr-hook-smoke.sh` (feeds the hook fixture inputs and asserts suggestion presence/absence). Also related: `tests/adr-skill-e2e.sh`, `tests/adr-skill-stress.sh` (not in CI), `tests/adr-helper-smoke.sh`.

Repo conventions: plain `.mjs` Node, no comments, explicit small functions.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Syntax | `node --check claude/hooks/detect-adr-signal.mjs` | exit 0 |
| Hook smoke | `bash tests/adr-hook-smoke.sh` | exit 0 |
| Manual probe (no signal) | `echo '{"last_assistant_message":"done, tests pass","cwd":"."}' \| node claude/hooks/detect-adr-signal.mjs` | no output, exit 0 |
| Manual probe (signal, this repo dirty state dependent) | `echo '{"last_assistant_message":"we decided to use X instead of Y","cwd":"."}' \| node claude/hooks/detect-adr-signal.mjs` | output only if repo has structural change |

## Scope

**In scope**:
- `claude/hooks/detect-adr-signal.mjs`
- `tests/adr-hook-smoke.sh` (only to ADD a case, if step 3 requires one)

**Out of scope**:
- `claude/settings.workflow-hooks.json` (wiring unchanged)
- `claude/skills/adr/**` (the skill itself)
- Other hooks.

## Git workflow

- Branch: `advisor/006-adr-hook-short-circuit`
- Commit: `perf(claude): short-circuit adr stop hook on cheap text check`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Reorder the main condition to cheapest-first

Change lines 101-105 so the pure-text check runs before any git subprocess:

```js
if (
  hasDecisionSignal(input) &&
  hasStructuralChange(cwd) &&
  !adrAlreadyTouched(cwd)
) {
```

Semantics are identical (pure conjunction, all three functions are side-effect-free), but a turn without decision markers now exits after zero subprocesses (when `last_assistant_message` is provided by the harness) and `adrAlreadyTouched`'s git call only runs when the first two pass.

**Verify**: `node --check claude/hooks/detect-adr-signal.mjs` → exit 0; both manual probes behave as in the table above.

### Step 2: Bound the transcript fallback

In `lastAssistantFromTranscript`, avoid parsing the whole file when only the tail matters: read the file once, but iterate only the last 200 non-empty lines (the last assistant message is at or near the end of the JSONL transcript):

```js
const lines = raw.split("\n").filter((l) => l.trim() !== "").slice(-200);
```

Keep the backwards iteration as is. (A full streaming/partial read is not worth the complexity for a 5s-timeout hook; slicing caps the JSON.parse work, which dominates.)

**Verify**: `bash tests/adr-hook-smoke.sh` → exit 0.

### Step 3: Confirm smoke coverage of the fallback path

Read `tests/adr-hook-smoke.sh`. If no existing case exercises the transcript-fallback path (input WITHOUT `last_assistant_message` but WITH `transcript_path`), add one: write a temp JSONL with a final assistant entry containing "we decided", pass it as `transcript_path`, assert the suggestion fires (in a temp git repo with a structural change, matching how the existing cases set up their fixture repos — mirror the script's existing setup helpers exactly).

**Verify**: `bash tests/adr-hook-smoke.sh` → exit 0, case count increased if you added one.

## Test plan

- Existing `tests/adr-hook-smoke.sh` cases are the regression net (suggestion fires / doesn't fire).
- New case (step 3, only if missing): transcript-fallback path with a decision marker in the last assistant entry.

## Done criteria

- [ ] Condition order is signal → structural → adr-touched (grep the file)
- [ ] Transcript fallback slices to the last 200 non-empty lines
- [ ] `bash tests/adr-hook-smoke.sh` exits 0
- [ ] `node --check claude/hooks/detect-adr-signal.mjs` exits 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `tests/adr-hook-smoke.sh` reveals the hook input in real Claude sessions does NOT include `last_assistant_message` AND the smoke asserts transcript parsing of entries beyond the last 200 lines (would make the slice a behavior change) — report instead of raising the cap blindly.
- Any smoke case fails after step 1 (would mean the functions are not order-independent — investigate, do not force).

## Maintenance notes

- If Claude Code's Stop-hook payload ever drops `last_assistant_message`, the transcript fallback becomes the hot path again; the 200-line slice keeps it bounded.
- Reviewer: confirm no semantic change — same three predicates, pure reorder + bounded fallback.
