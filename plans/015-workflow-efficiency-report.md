# Plan 015: scripts/workflow-efficiency-report — measurable health metrics for the workflow layer

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- scripts/ workflow/ claude/ pi/extensions/ tests/`
> This plan only READS those paths; large drift just changes the numbers, not
> the method. Proceed unless a whole directory it measures disappeared.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

The repo's stated architecture is "shared contracts + thin adapters" (`workflow/spec.md:125-145`). Whether reality matches is currently a feeling, not a number: the two router adapters are 452 and 392 lines; instruction files duplicate whole sections; smoke suites grow without anyone watching their duration. A small read-only report script turns the architecture claim into trackable metrics, so drift shows up as a diff in numbers rather than an audit finding a year later. Honest caveat, recorded up front: this report has no automated consumer yet — its value is periodic human review and before/after evidence in refactor PRs (e.g. plans 001/003 landing should visibly move `adapter_total_lines` and `duplicate_section_count`). If it goes unread for a quarter, delete it; that exit is part of the design.

## Current state

- `scripts/` house style: bash, `set -euo pipefail`, `status_line`-ish aligned output (see `scripts/deploy-workflow`), no external deps beyond coreutils/`jq`.
- Measurable surfaces at `1f89823` (baselines the script should roughly reproduce):
  - Shared contracts: `workflow/*.md` (8 files, 575 lines total), `workflow/skills/*.md` (3 files, 218 lines).
  - Adapters: `claude/hooks/workflow-router-lib.mjs` (452 lines), `pi/extensions/lib/workflow-router-runtime.ts` (392 lines), `claude/commands/*.md` (30 files), `pi/skills/` (list at run time).
  - Known duplicate pair: `codex/workflow/ticket-template.md` = `workflow/ticket-template.md` (same blob).
  - Instruction duplication: `claude/CLAUDE.md` vs `pi/AGENTS.md` share ~5 near-verbatim sections (plan 003 reduces this; the metric tracks it).
  - Smoke suites: the `tests/*.sh` files invoked by `.github/workflows/agentic-infra.yml`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Script syntax | `bash -n scripts/workflow-efficiency-report` | exit 0 |
| Run | `scripts/workflow-efficiency-report` | metrics on stdout, exit 0 |
| JSON mode | `scripts/workflow-efficiency-report --json \| jq empty` | exit 0 |
| Smoke | `bash tests/workflow-efficiency-report-smoke.sh` | exit 0 |

## Scope

**In scope**:
- `scripts/workflow-efficiency-report` (new, read-only)
- `tests/workflow-efficiency-report-smoke.sh` (new)
- `.github/workflows/agentic-infra.yml` (run the smoke, NOT the report itself as a gate)

**Out of scope**:
- Thresholds/gates on the metrics (no CI failure on "too many lines" — numbers first, judgments later).
- Timing the smoke suites by executing them inside the report (the report must stay instant; suite duration comes from CI logs, the report only lists the suites and their line counts).
- Any write anywhere.

## Git workflow

- Branch: `advisor/015-efficiency-report`
- Commit: `feat(scripts): add read-only workflow efficiency report`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Write the script

`scripts/workflow-efficiency-report [--json]`, read-only, computing:

| metric | method |
|--------|--------|
| `shared_contract_files` / `shared_contract_lines` | count + `wc -l` over `workflow/*.md workflow/skills/*.md` |
| `adapter_files` / `adapter_total_lines` | `claude/hooks/*.mjs`, `pi/extensions/*.ts pi/extensions/lib/*.ts` (excluding `__tests__`), `claude/commands/*.md`, `pi/skills/**/*.md` if present |
| `router_adapter_lines` | the two classifier files, listed individually — the "thin adapter" headline number |
| `exact_duplicate_pairs` | `git ls-files \| xargs git hash-object` (or `git ls-tree -r HEAD` blob hashes) grouped by hash, pairs listed |
| `instruction_dup_sections` | count of `## <heading>` present in BOTH `claude/CLAUDE.md` and `pi/AGENTS.md` (comm on sorted heading lists) |
| `smoke_suites` / `smoke_total_lines` | the `bash tests/*.sh` entries parsed from `.github/workflows/agentic-infra.yml` + `wc -l` each |
| `source_of_truth_conflicts` | count of routing-surface files: prose locations matching `grep -l "plan-loop" workflow/spec.md claude/CLAUDE.md` + the 2 classifiers (the "how many places define routing" number; hardcode the candidate list, count matches) |

Output: aligned `metric value` lines; `--json` emits one object via `jq -n` assembly. Exit 0 always (reporting, not gating).

**Verify**: `scripts/workflow-efficiency-report` → plausible numbers matching the baselines above (452/392 for the routers, 1 exact-duplicate pair); `--json | jq empty` → exit 0.

### Step 2: Smoke test

`tests/workflow-efficiency-report-smoke.sh` (house style): run the script twice (text + json); assert exit 0 both times; assert json parses and contains the seven metric keys; assert `router_adapter_lines` reports both classifier paths; assert the script made no writes (`git status --porcelain` empty before/after — run from a clean state or compare snapshots).

**Verify**: `bash tests/workflow-efficiency-report-smoke.sh` → exit 0.

### Step 3: CI wiring

Add `bash tests/workflow-efficiency-report-smoke.sh` to the CI smoke list.

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/agentic-infra.yml'))"` → exit 0.

## Test plan

Step 2's assertions. The metric VALUES are not asserted (they change with every refactor by design); only presence, parseability, and read-only behavior are pinned.

## Done criteria

- [ ] `scripts/workflow-efficiency-report` runs in <2s, exit 0, seven metrics
- [ ] `--json` output parses; keys stable
- [ ] Baseline run's output pasted in your report (this becomes the reference numbers for plans 001/003 before/after)
- [ ] `bash tests/workflow-efficiency-report-smoke.sh` exits 0; CI wired; YAML parses
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Any metric requires executing test suites or agents to compute — that metric is out of scope, emit `null` for it and note why.
- `pi/skills/` doesn't exist or has an unexpected layout — emit what is measurable, note the gap; do not guess paths.

## Maintenance notes

- Deliberate sunset clause: if no PR cites these numbers within a quarter, delete script + smoke (one commit) — a report nobody reads is negative value.
- Plans 001 (router unification pressure) and 003 (instruction dedup) should quote before/after values from this report in their PRs if it lands first.
- Do not grow this into a dashboard; it is `wc -l` with a contract.
