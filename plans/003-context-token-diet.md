# Plan 003: Cut per-session and per-prompt context weight (router injection + duplicated instruction files)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- claude/hooks/workflow-router-lib.mjs pi/extensions/lib/workflow-router-runtime.ts claude/CLAUDE.md pi/AGENTS.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-router-parity-port.md (both routers must be aligned before editing injection logic in both)
- **Category**: perf
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

Every agent session in this setup pays a fixed context tax, and every single prompt pays a marginal one. Measured at `1f89823`:

- `claude/CLAUDE.md` ≈ 7,467 chars (~1,870 tokens) and `pi/AGENTS.md` ≈ 4,947 chars (~1,240 tokens). Five whole sections are near-verbatim copies between them (Identity, Style, Cognition, Anti-Sycophancy, Contrarian Stance) plus large overlaps in Code, Reviews, Tickets, Git.
- The workflow router injects a ~20-line block (~150–200 tokens) into context on EVERY non-slash prompt — including trivial ones classified as `answer`, the default route, where the block adds nothing (its content is "route: answer, no artifact, answer delivered" plus boilerplate).

Published evidence says this weight is not just money: agent performance degrades with context length across all tested models (Chroma "Context Rot", 2025), and token budget explained ~80% of performance variance in Anthropic's multi-agent system (Anthropic engineering, 2025). Cutting the `answer`-route injection alone removes ~200 tokens × most prompts of every session.

## Current state

### Router injection (both runtimes)

- `claude/hooks/workflow-router-lib.mjs:417-429` — `userPromptSubmitDecision` always injects when the prompt is non-empty and not a slash command:

```js
export function userPromptSubmitDecision(event) {
  const prompt = String(event.prompt || "");
  if (!shouldInjectRouteContext(prompt)) return null;

  const planStatus = readPlanStatus(event.cwd || process.cwd());
  const decision = classifyWorkflowRoute(prompt, { planStatus });
  return {
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: buildRouteContext(decision),
    },
  };
}
```

- `buildRouteContext` (`:352-385`) emits ~20 lines including 4 fixed boilerplate lines about Task*/capability labels regardless of route.
- Pi side: `pi/extensions/workflow-router.ts:44-62` calls `appendWorkflowRouterGuidance(event.systemPrompt, decision)` unconditionally after `shouldInjectWorkflowRouter`; the guidance block is built at `pi/extensions/lib/workflow-router-runtime.ts:355-373`.
- The `answer` decision shape (`workflow-router-lib.mjs:431-441`): `route: "answer"`, `command: "none"`, `writeAllowed: false`. Several distinct reasons produce it (empty, slash, Linear read, read-only/question, prompt-artifact, fallback).

### Duplicated instruction files

- `claude/CLAUDE.md` header says: "Keep this aligned with `pi/AGENTS.md`" — a manual sync instruction.
- Sections `## Identity`, `## Style`, `## Cognition`, `## Anti-Sycophancy`, `## Contrarian Stance`, `## Tickets`, most of `## Code` and `## Reviews` and `## Git` are copies of `pi/AGENTS.md` sections of the same names (compare the two files side by side; wording differs only in a handful of lines, e.g. CLAUDE.md Code adds the long "No comments" paragraph and Node runtime line, AGENTS.md Code has Bun/UI lines).
- Claude Code supports `@path` imports inside CLAUDE.md (this user already uses `@~/work/CLAUDE.md` in `~/CLAUDE.md`). Whether Pi's AGENTS.md loader supports any import mechanism is UNKNOWN — do not assume it does.

### Deployment layout (matters for edits)

- `pi/AGENTS.md` is symlinked to `~/.pi/agent/AGENTS.md` (see repo `AGENTS.md` "Symlink layout").
- `claude/CLAUDE.md` is the repo-local Claude adapter (loaded when working in this repo).
- `tests/workflow-docs-smoke.sh` and `tests/claude-skills-smoke.sh` assert doc invariants — run them after edits.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Token weight measure | `wc -c claude/CLAUDE.md pi/AGENTS.md` | chars; /4 ≈ tokens |
| Claude hook probe | `echo '{"prompt":"quelle heure est-il ?","cwd":"."}' \| node claude/hooks/workflow-router.mjs` | see step 1 |
| Pi tests | `cd pi && bun test ./extensions/__tests__/*.test.ts` | all pass |
| Claude hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |
| Docs smoke | `bash tests/workflow-docs-smoke.sh && bash tests/claude-skills-smoke.sh` | exit 0 |

## Scope

**In scope**:
- `claude/hooks/workflow-router-lib.mjs` (injection condition only — not classification)
- `pi/extensions/lib/workflow-router-runtime.ts` (same)
- `pi/extensions/workflow-router.ts` (only if the skip must live in the adapter)
- `pi/extensions/__tests__/` (adjust/add tests for the skip)
- `claude/CLAUDE.md` (deduplication)
- `tests/fixtures/claude-hooks/` + `tests/claude-hooks-smoke.sh` (only if existing fixtures assert injection on answer routes)

**Out of scope**:
- `pi/AGENTS.md` — it stays the canonical full file (Pi has no known import mechanism; trimming it would break Pi sessions).
- `workflow/spec.md` — plan 005's territory.
- Classification branches/patterns in either classifier — plans 001/002.
- `~/.claude/CLAUDE.md` and anything under `$HOME` — user-managed; changing deployed copies is the operator's action, not the executor's.

## Git workflow

- Branch: `advisor/003-context-token-diet`
- Commits: `perf(workflow): skip router injection for answer route` then `docs(claude): deduplicate CLAUDE.md against pi/AGENTS.md`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Record the baseline

Run and save output:
- `wc -c claude/CLAUDE.md pi/AGENTS.md`
- `echo '{"prompt":"quelle heure est-il ?","cwd":"."}' | node claude/hooks/workflow-router.mjs` → currently prints a JSON with `additionalContext` containing `Route: answer`.

**Verify**: both outputs captured in your report.

### Step 2: Skip injection for `answer` routes — Claude side

In `claude/hooks/workflow-router-lib.mjs`, change `userPromptSubmitDecision` to return `null` when `decision.route === "answer"`:

```js
const decision = classifyWorkflowRoute(prompt, { planStatus });
if (decision.route === "answer") return null;
```

Do NOT change `classifyWorkflowRoute` itself — the `answer` decision must keep existing (the Pi extension `tasks-till-done.ts:86` calls the classifier directly and depends on its output shape).

**Verify**:
- `echo '{"prompt":"quelle heure est-il ?","cwd":"."}' | node claude/hooks/workflow-router.mjs` → empty output (no JSON)
- `echo '{"prompt":"corrige le bug de login","cwd":"."}' | node claude/hooks/workflow-router.mjs` → JSON containing `"Route: plan-implement"`

### Step 3: Skip injection for `answer` routes — Pi side

In `pi/extensions/workflow-router.ts`, after computing `decision`, return `undefined` (still calling `routablePi.appendEntry` is optional — keep the appendEntry call so the decision stays observable in the session log, but skip the `systemPrompt` mutation):

```ts
if (decision.route === "answer") return undefined;
```

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → identify any test asserting injection for answer routes; if one exists, update its expectation to "no injection" (that is the new intended behavior). All pass afterward.

### Step 4: Fix fixtures that asserted answer-route injection

Read `tests/claude-hooks-smoke.sh`; find fixtures whose expected behavior is injection with route `answer` (candidates from the fixture list: `router-spec-question.json`, `router-linear-read.json`, `router-ready-read-only.json`, `router-short-relance.json`). Update their expectations to "no output". Fixtures asserting non-answer routes stay untouched.

**Verify**: `bash tests/claude-hooks-smoke.sh` → exit 0.

### Step 5: Deduplicate `claude/CLAUDE.md`

Rewrite `claude/CLAUDE.md` keeping ONLY Claude-specific content, replacing duplicated sections with one pointer line. Target structure:

```markdown
# CLAUDE.md - etabli

Claude Code adapter. Shared identity, style, cognition, code, review, ticket,
anti-sycophancy, and git rules live in `pi/AGENTS.md` — they apply here
verbatim; read that file first.

## Claude-specific
<only the content that differs: Source of Truth block, Workflow routing list
(until plan 005 trims it), /verify-workflow vs native /verify note, /goal
usage, Subagent Model section, workflow-hooks pointer, Safety note,
Node/Vitest runtime line, test-naming convention, REVIEW.md prohibition,
plan-archive rule>
```

Rules:
- Every line you delete from CLAUDE.md must exist (semantically) in `pi/AGENTS.md`; every line that does NOT exist there stays. Do the comparison section by section.
- Keep the file valid for a reader who opens only it: the pointer to `pi/AGENTS.md` must be in the first ten lines.

**Verify**:
- `wc -c claude/CLAUDE.md` → at least 40% smaller than baseline from step 1.
- `bash tests/workflow-docs-smoke.sh && bash tests/claude-skills-smoke.sh` → exit 0.

### Step 6: Full regression

**Verify**: `cd pi && bun test ./extensions/__tests__/*.test.ts` → all pass; `bash tests/claude-hooks-smoke.sh` → exit 0; `node --check claude/hooks/workflow-router-lib.mjs` → exit 0.

## Test plan

- New/updated expectations: answer-route → no injection (both runtimes), non-answer routes → unchanged injection.
- Add one Pi unit test if none exists: `classifyWorkflowRoute` still returns full `answer` decisions (guard for `tasks-till-done` consumer).
- Pattern: existing tests in `pi/extensions/__tests__/`.

## Done criteria

- [ ] Answer-route probe (step 2) produces no hook output; plan-implement probe produces the full block
- [ ] `cd pi && bun test ./extensions/__tests__/*.test.ts` exits 0
- [ ] `bash tests/claude-hooks-smoke.sh` exits 0
- [ ] `bash tests/workflow-docs-smoke.sh` exits 0
- [ ] `wc -c claude/CLAUDE.md` ≥40% below the step-1 baseline, and a before/after token estimate (chars/4) is in the final report
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Anything in `pi/extensions/` besides `tasks-till-done.ts` consumes the router `answer` decision in a way the skip would break (search: `grep -rn "classifyWorkflowRoute\|workflow-router" pi/extensions --include="*.ts" | grep -v __tests__ | grep -v lib/workflow-router-runtime`).
- A CLAUDE.md section looks duplicated but has semantic differences you cannot classify as "Claude-specific vs shared" — list the diffs and stop instead of guessing.
- `tests/workflow-docs-smoke.sh` asserts exact CLAUDE.md content that contradicts the dedup — report the assertion.

## Maintenance notes

- After this lands, the operator should mirror the CLAUDE.md dedup into their deployed `~/.claude/CLAUDE.md` (out of executor scope).
- Future routing additions: remember `answer` no longer injects; if a new lightweight route needs context, inject explicitly rather than reverting the skip.
- The 4 fixed boilerplate lines in `buildRouteContext` (Task*/capability labels) are a further ~60-token cut deliberately deferred: they encode contract language that plan 005 may relocate into spec.md first.
