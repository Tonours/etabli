# Plan 012: Event ledger convention for long runs (.workflow/<slug>/events.jsonl) with helper and validation

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- workflow/ scripts/ tests/ .gitignore`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

Long-running workflow runs (multi-packet orchestrations, autonomous plan loops) currently leave state as prose scattered across `plan.md`, `orchestration.md`, packet files, and the chat itself. Resuming or handing off a run means re-reading everything. The production-agent literature (OpenHands SDK: event log + resumable state; Temporal: deterministic workflow, journaled non-deterministic decisions) converges on one mechanism: an append-only event log. This repo already has the natural place for it — the `.workflow/<slug>/` run directory convention (see `.workflow/workflow-router-audit/` with its `state.json` + `packets/` + `results/`) — but no event stream. This plan adds the convention (documented contract), a tiny append/validate helper, and a smoke test. Agents append events by following the contract; nothing is auto-instrumented (hooks stay stateless routers/guards — instrumenting them would couple per-prompt hooks to run-directory state they cannot reliably locate).

## Current state

- `.workflow/<slug>/` — existing local run-directory convention (gitignored; see `.gitignore` and `.workflow/workflow-router-audit/` containing `state.json`, `plan.md`, `orchestration.md`, `packets/`, `results/`). `state.json` holds `{title, slug, created_at, status, approval, packets:[{id,name,status}]}`.
- `workflow/spec.md` — the canonical contract; has no run-directory or event section.
- `workflow/skills/orchestration.md` — the orchestration contract; its "Acceptance Evidence" section (lines 76-90) lists what each packet must leave behind, and Codex runtime notes (line 127) mention "simulated packets under `.workflow/<slug>/`". Events would be the durable form of that evidence.
- `scripts/` — bash, `set -euo pipefail`, `status_line`-style output (see `scripts/deploy-workflow` for the house style). CI syntax-checks `scripts/` (`bash -n` loop in `.github/workflows/agentic-infra.yml:19-25`).
- No `jq` dependency issue: CI installs nothing for it (ubuntu-latest ships jq); local macOS has it (used by CI JSON validation step conventions).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Helper syntax | `bash -n scripts/workflow-event` | exit 0 |
| New smoke | `bash tests/workflow-event-smoke.sh` | exit 0 |
| Docs smoke | `bash tests/workflow-docs-smoke.sh` | exit 0 |
| jq present | `command -v jq` | path |

## Scope

**In scope**:
- `workflow/events.md` (new: the convention contract)
- `scripts/workflow-event` (new helper: append + validate)
- `tests/workflow-event-smoke.sh` (new)
- `workflow/spec.md` (one short pointer paragraph)
- `workflow/skills/orchestration.md` (one short pointer in "Acceptance Evidence")
- `.github/workflows/agentic-infra.yml` (add the smoke)

**Out of scope**:
- Instrumenting hooks/extensions to auto-emit events (deliberate: hooks are per-prompt and stateless; auto-emission is a future decision once the manual convention proves useful).
- Migrating `state.json` or existing `.workflow/` runs.
- Adding the events convention to `scripts/deploy-workflow` FILES (scaffolded projects get it via `workflow/spec.md`'s pointer only for now — one source, no copies; revisit if projects ask for the file itself).

## Git workflow

- Branch: `advisor/012-event-ledger`
- Commit: `feat(workflow): add run event ledger convention and helper`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Write `workflow/events.md`

Content contract (keep under ~80 lines):

- Location: `.workflow/<slug>/events.jsonl`, append-only, one JSON object per line, never rewritten; the run dir is local/gitignored.
- Event shape: `{"ts": "<ISO8601>", "event": "<type>", "run": "<slug>", "detail": {...}}` — `detail` is type-specific and optional.
- Event types (closed list, extend by editing this file):
  `route_decided`, `plan_created`, `adversary_completed`, `file_changed`,
  `validation_run`, `validation_failed`, `retry_classified`,
  `human_checkpoint`, `archive_written`, `completed`, `blocked`.
- Detail conventions per type in one table (e.g. `route_decided` → `{route, reason}`; `validation_run` → `{command, exit}`; `blocked` → `{reason, needed_input}`; `retry_classified` → `{failure_class, next_action}` — align wording with `workflow/skills/orchestration.md` "Retry And Error Rules").
- Consumption: "resume = read `state.json` for structure, replay `events.jsonl` for history; the last `completed|blocked` event is the run's terminal state; a run with neither is in progress."
- Writing rule: agents append via `scripts/workflow-event append` (or an equivalent single `printf >> ` line when the script is unavailable in a scaffolded project); never edit prior lines.

### Step 2: Write `scripts/workflow-event`

Bash, house style. Two subcommands:

- `workflow-event append <slug> <event-type> [json-detail]` — validates: event type in the closed list; `json-detail` (when given) parses with `jq empty`; then appends the line with `ts` from `date -u +%Y-%m-%dT%H:%M:%SZ` to `.workflow/<slug>/events.jsonl` (creating the directory if missing). Rejects unknown types with exit 2 and the allowed list on stderr.
- `workflow-event validate <slug>` — exits 0 when every line parses (`jq -e . ` per line), every `event` is in the closed list, and timestamps are non-decreasing; prints `N events, ok` or the first offending line number.

Keep the closed list in ONE place in the script (an array) — `workflow/events.md` documents it; the smoke test (step 3) asserts the two stay in sync.

**Verify**: `bash -n scripts/workflow-event` → exit 0; manual round-trip:
```
d=.workflow/plan012-selftest && scripts/workflow-event append plan012-selftest route_decided '{"route":"plan-loop"}' && scripts/workflow-event validate plan012-selftest && rm -rf "$d"
```
→ `1 events, ok`, exit 0.

### Step 3: Write `tests/workflow-event-smoke.sh`

Mirror the house harness (`set -euo pipefail`, mktemp, trap, assert helpers as in `tests/claude-hooks-smoke.sh`). Run the script with `HOME`-independent paths against a temp `.workflow` (add a `--dir <path>` option to the helper, defaulting to `./.workflow`, so tests never touch the repo's real run dirs). Cases:
1. append + validate happy path (3 events, ok, exit 0)
2. unknown event type → exit 2, stderr lists allowed types
3. malformed detail JSON → exit 2
4. hand-corrupt one line → `validate` exits 1, names the line
5. sync check: every type listed in `workflow/events.md` appears in the script's array and vice versa (grep-based; extract the list from both files and `diff`)

**Verify**: `bash tests/workflow-event-smoke.sh` → exit 0.

### Step 4: Pointer paragraphs

- `workflow/spec.md`: after the "Rules" section, add 3 lines: long or multi-packet runs record durable progress as events in `.workflow/<slug>/events.jsonl` per `workflow/events.md`; resumption reads the ledger instead of chat history; `completed`/`blocked` events are the terminal evidence.
- `workflow/skills/orchestration.md` "Acceptance Evidence": add one bullet — "durable event trail per `workflow/events.md` when the run uses a `.workflow/<slug>/` directory".

**Verify**: `bash tests/workflow-docs-smoke.sh` → exit 0 (if it fails on an assertion about spec.md shape, reconcile that assertion minimally; any other failure → STOP).

### Step 5: CI wiring

Add `bash tests/workflow-event-smoke.sh` to the smoke list in `.github/workflows/agentic-infra.yml`.

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/agentic-infra.yml'))"` → exit 0.

## Test plan

Step 3's five cases; plus docs smoke green. The doc↔script sync check (case 5) is the drift guard.

## Done criteria

- [ ] `workflow/events.md` exists with the closed type list and detail table
- [ ] `scripts/workflow-event append|validate` work per the manual round-trip
- [ ] `bash tests/workflow-event-smoke.sh` exits 0 (5 cases)
- [ ] `bash tests/workflow-docs-smoke.sh` exits 0
- [ ] CI references the new smoke; YAML parses
- [ ] No writes under the repo's real `.workflow/` left behind (`ls .workflow/` unchanged vs baseline)
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `jq` unavailable on the target platform matrix (macOS local + ubuntu CI both ship it; if the smoke env lacks it, report rather than vendoring a JSON parser).
- `tests/workflow-docs-smoke.sh` fails for a reason other than a spec.md-shape assertion.
- You feel the need to auto-emit events from hooks to make the ledger useful — that is the explicitly deferred step; the convention must prove itself manually first.

## Maintenance notes

- Event-type additions: edit BOTH the script array and `workflow/events.md`; smoke case 5 fails otherwise — that is intended.
- If the ledger proves useful, natural next steps (new plans, not scope creep): `workflow-event` emitting from `/implement`-family command contracts, and a `workflow-event report <slug>` renderer. Auto-instrumentation of `tasks-till-done` is the Pi-side candidate.
- Interaction with plan 013: `human_checkpoint` events are where checkpoint decisions (plan 016) get journaled.
