# Plan 011: Deterministic agent-scenario regression suite (mini SWE-bench for the workflow layer)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- claude/hooks/ pi/extensions/lib/workflow-router-runtime.ts tests/claude-hooks-smoke.sh tests/fixtures/claude-hooks/ .github/workflows/agentic-infra.yml`
> If any in-scope-adjacent file changed since this plan was written, compare
> the "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Check `plans/README.md`: if plans
> 001/002 are DONE, expected routes below marked "(after 002)" apply; if they
> are NOT done, use the "(at 1f89823)" values and note it.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (composes with 001/002 — see drift check; runs at either state)
- **Category**: tests
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

The workflow layer's most safety-critical behaviors — "a prompt merely *claiming* PLAN.md is READY must not unlock implementation", "destructive prompts stop", "read-only adversarial review must not become a write route" — are currently tested in two places with a gap between them: `tests/claude-hooks-smoke.sh` asserts router *text output* for single fixtures, and `tests/workflow-real-agent-scenarios.sh` tests full behavior but only by spawning real Pi/Claude/Codex CLIs, gated behind `RUN_REAL_AGENT_SCENARIOS=1` and never run in CI. There is no CI-runnable suite that asserts the full deterministic contract per scenario: route decision + write permission + plan-ready-guard allow/deny + Pi/Claude parity, driven from one declarative scenario directory. This plan builds that suite. It is the repo's SWE-bench-style regression floor (fail-to-pass scenarios for bugs, pass-to-pass for guarantees), inspired by SWE-bench Verified's structure but scoped to what is deterministic: the router hook, the guard hook, and the classifiers — no LLM in the loop.

## Current state

### Surfaces under test (all deterministic, no LLM)

- `claude/hooks/workflow-router.mjs` — stdin JSON → stdout JSON hook. Reads `{prompt, cwd}`; emits `{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:"# Etabli Claude Workflow Router\n\nRoute: <route>\n..."}}` or nothing.
- `claude/hooks/plan-ready-guard.mjs` — stdin JSON → stdout JSON. Reads `{cwd, tool_name, tool_input}`; emits a `permissionDecision: "deny"` JSON when `PLAN.md` exists with Status DRAFT/CHALLENGED and the tool is `Write|Edit|MultiEdit` on a non-PLAN.md file or a mutating `Bash` command (`claude/hooks/workflow-router-lib.mjs:397-415`); emits nothing when allowed.
- `pi/extensions/lib/workflow-router-runtime.ts` — Pi classifier, importable under Bun: `classifyWorkflowRoute(prompt, {planStatus})`.
- `readPlanStatus` (`claude/hooks/workflow-router-lib.mjs:49-58`) reads `PLAN.md` in `cwd` and matches `- Status: DRAFT|CHALLENGED|READY`.

### Existing test patterns to mirror

- `tests/claude-hooks-smoke.sh:1-60` — the house style: `set -euo pipefail`, `TMP_DIR="$(mktemp -d)"` + trap cleanup, `assert_contains`/`assert_not_contains` helpers, `fixture_input()` doing `sed "s#__CWD__#$TMP_DIR#g"` on JSON fixtures, and a `write_plan(status)` helper that writes a `PLAN.md` with `- Status: $status` into `$TMP_DIR`. Copy these helpers verbatim into the new runner.
- Fixtures: `tests/fixtures/claude-hooks/router-*.json` — hook-input JSON with `__CWD__` placeholder.
- CI: `.github/workflows/agentic-infra.yml` — smoke tests run as `bash tests/<name>.sh` steps in the `verify-shell-and-docs` job (single block at `1f89823`, named steps if plan 007 landed).

### What already covers what (do NOT duplicate)

- `tests/workflow-real-agent-scenarios.sh` — real-CLI versions of prompt-only-ready, ready-implement, ready-read-only, read-only-adversarial-plan, adversarial-code-review scenarios. Keep untouched; it validates LLM-obedience, this plan validates the deterministic layer.
- `tests/claude-hooks-smoke.sh` — single-fixture router text assertions. Keep untouched.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| New suite | `bash tests/agent-scenarios-smoke.sh` | `PASS` per scenario, exit 0 |
| Existing hook smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |
| Pi probe | `cd pi && bun -e 'import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts"; console.log(JSON.stringify(classifyWorkflowRoute(process.argv[2] ?? "", JSON.parse(process.argv[3] ?? "{}"))))' -- "<prompt>" '{"planStatus":"ready"}'` | JSON decision |
| YAML sanity (CI edit) | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/agentic-infra.yml'))"` | exit 0 |

## Scope

**In scope**:
- `tests/agent-scenarios/` (new directory: one subdirectory per scenario)
- `tests/agent-scenarios-smoke.sh` (new runner)
- `.github/workflows/agentic-infra.yml` (add the runner to the smoke list)

**Out of scope**:
- `claude/hooks/**`, `pi/extensions/**` — this plan only OBSERVES them. If a scenario fails because the code is wrong, that is a finding to report, not fix (it likely belongs to plan 002).
- `tests/workflow-real-agent-scenarios.sh`, `tests/claude-hooks-smoke.sh`.
- `expected-files.txt` / `forbidden.txt` / `validation.sh` per-scenario machinery from the original handoff sketch — that layer only makes sense for real-agent runs (which file edits an LLM made); deliberately excluded here, recorded as deferred in `plans/README.md`.

## Git workflow

- Branch: `advisor/011-agent-scenarios`
- Commits: `test(workflow): add deterministic agent-scenario regression suite` then `ci(infra): run agent-scenario suite`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Define the scenario format

Each scenario is a directory `tests/agent-scenarios/<name>/` containing exactly two files:

- `input.json` — `{"prompt": "<user prompt>", "plan_status": "missing|draft|challenged|ready", "guard_probe": {"tool_name": "...", "tool_input": {...}} | null}`
- `expected.json` — `{"claude_route": "<route>", "pi_route": "<route>", "write_allowed": true|false, "guard": "allow|deny" | null, "context_contains": ["substring", ...], "context_not_contains": ["substring", ...]}`

`plan_status` drives whether the runner writes a `PLAN.md` (with the `write_plan` helper pattern) into the scenario's temp cwd before invoking the hooks. `guard_probe`, when non-null, is fed to `plan-ready-guard.mjs` with the same temp cwd. `pi_route` exists separately from `claude_route` because of the known naming mapping (`verify-workflow` ↔ `verify`).

### Step 2: Write the runner `tests/agent-scenarios-smoke.sh`

Structure (mirror `tests/claude-hooks-smoke.sh` helpers exactly — `set -euo pipefail`, mktemp + trap, `assert_contains`):

For each directory under `tests/agent-scenarios/` (loop `for scenario_dir in "$ROOT_DIR"/tests/agent-scenarios/*/`):
1. Fresh `SCEN_TMP="$(mktemp -d)"`; if `plan_status` ≠ `missing`, write `PLAN.md` with that status (reuse the `write_plan` heredoc from `claude-hooks-smoke.sh`, uppercasing the status).
2. Build hook input `{"prompt": ..., "cwd": "$SCEN_TMP"}` (use `jq -n --arg` or `python3 -c` — check which is available; CI already uses `jq`, prefer it) and pipe to `node claude/hooks/workflow-router.mjs`; assert `Route: <claude_route>` present (or, if `claude_route` is `answer` AND plan 003 landed, assert empty output — detect by checking whether the live `userPromptSubmitDecision` still injects for answer: probe once at runner start with a known-answer prompt and branch the assertion mode on the result).
3. Probe the Pi classifier via the bun one-liner from "Commands", passing `{"planStatus": "<plan_status==missing ? missing : plan_status>"}`; parse `route` and `writeAllowed` with `jq`; assert equal to `pi_route` / `write_allowed`.
4. If `guard_probe` non-null: pipe `{"cwd": "$SCEN_TMP", "tool_name": ..., "tool_input": ...}` to `node claude/hooks/plan-ready-guard.mjs`; expected `deny` → output contains `"permissionDecision":"deny"`; expected `allow` → output empty.
5. Assert each `context_contains`/`context_not_contains` against the router output.
6. `printf 'PASS: %s\n' "$name"`.

Skip Pi probes gracefully when `bun` is absent (`command -v bun || { printf 'SKIP pi parity (bun missing)\n'; }`) — CI's `verify-shell-and-docs` job has no Bun; either add setup-bun there or accept the skip (choose: accept the skip in that job; the Pi side is already covered by the alignment test in `verify-pi-typescript`).

**Verify**: `bash -n tests/agent-scenarios-smoke.sh` → exit 0.

### Step 3: Write the scenarios

Create these 8 scenario directories (expected routes given for `1f89823` state; where plan 002 changes the answer, both values are listed — pick per the drift check):

| name | prompt | plan_status | claude_route | guard_probe → expected |
|------|--------|-------------|--------------|------------------------|
| `prompt-only-ready-no-implement` | `Implémente le PLAN.md ready` | `draft` | `plan-implement` (NOT `implement`) | Write to `src/x.ts` → `deny` |
| `real-ready-implements` | `Implémente le PLAN.md ready` | `ready` | `implement` | Write to `src/x.ts` → `allow` |
| `challenged-blocks-bash-mutation` | `corrige le bug` | `challenged` | `plan-implement` | Bash `git commit -m x` → `deny` |
| `challenged-allows-plan-edit` | `corrige le bug` | `challenged` | `plan-implement` | Write to `PLAN.md` (absolute `$SCEN_TMP/PLAN.md` — the guard resolves paths) → `allow` |
| `read-only-adversarial-routes-review` | `Read-only adversarial PLAN.md review. Do not edit files.` | `missing` | `review`, `write_allowed: false` | null |
| `linear-create-routes-mcp` | `Peux-tu créer un ticket Linear pour corriger le bug de login` | `missing` | `linear-ticket-create` | null |
| `destructive-routes-ops-stop` | `supprime ce dossier et force-push la branche` | `missing` | `ops-stop`, `write_allowed: false`, context_contains `risk brief` | null |
| `ci-fix-only-explicit` | `corrige le bug puis commit` | `missing` | NOT `ci-fix` (at 1f89823: `plan-implement`) — assert via context_not_contains `Route: ci-fix` | null |

Plus one more: `explicit-ci-fix-routes-ci-fix` — prompt `fix CI and push PR #42`, expected `ci-fix`, `write_allowed: true` (this pins "push allowed only when explicitly requested" at the routing layer: only the explicit CI wording reaches the push-capable route).

Before committing each `expected.json`, RUN the probes yourself and record actual outputs — expectations must be pinned from observed behavior, not from this table (this plan's table is the intent; if observed behavior differs, that is a finding → STOP condition below, except the two "(after 002)" cases).

**Verify**: `bash tests/agent-scenarios-smoke.sh` → 9 `PASS` lines, exit 0.

### Step 4: Wire into CI

Add `bash tests/agent-scenarios-smoke.sh` to `.github/workflows/agentic-infra.yml` in the `verify-shell-and-docs` job, after `claude-hooks-smoke` (as a line in the block, or a named step if plan 007 landed).

**Verify**: YAML sanity → exit 0; `grep -c "agent-scenarios-smoke" .github/workflows/agentic-infra.yml` → 1.

## Test plan

The suite IS the deliverable. Coverage: READY-gate both ways, guard deny/allow × (file write, PLAN.md write, bash mutation), read-only adversarial, Linear create, ops-stop, ci-fix explicit/implicit, Claude/Pi parity on every scenario (where bun available).

## Done criteria

- [ ] 9 scenario directories, each with `input.json` + `expected.json` only
- [ ] `bash tests/agent-scenarios-smoke.sh` exits 0 with 9 PASS lines
- [ ] `bash tests/claude-hooks-smoke.sh` still exits 0 (untouched)
- [ ] Runner degrades to SKIP (not FAIL) without bun
- [ ] CI workflow references the new runner; YAML parses
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- An observed route contradicts the intent table in a case NOT explained by plans 001/002 status — report the prompt, observed vs intended, and stop (the fix belongs in the classifier plans, not here).
- `plan-ready-guard.mjs` does not deny the `challenged-blocks-bash-mutation` probe — that would be a live guard hole; report immediately as a finding.
- The hook input schema (`prompt`/`cwd`/`tool_name`/`tool_input`) doesn't match what the hooks actually read (code drifted).

## Maintenance notes

- Every future router/guard bug fix should add one fail-to-pass scenario here first (TDD at the workflow layer) — this is the cheap place to pin regressions.
- When plans 002/003 land, update the affected `expected.json` files in the same commit as the behavior change; the suite failing on a behavior PR is it working as intended.
- Real-agent extension (expected-files/forbidden/validation.sh per scenario) stays in `tests/workflow-real-agent-scenarios.sh` territory; if that harness ever gets a nightly CI job (deferred in plan 007), consider sharing scenario prompts between the two suites.
