# Plan 014: Contract coverage smoke — every shared workflow contract is referenced, deployed, and duplicate-safe

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- workflow/ codex/workflow/ scripts/deploy-workflow scripts/deploy-codex tests/ .github/workflows/agentic-infra.yml`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

The workflow contract layer has three ways to rot silently, and none is tested today:

1. **Orphaned contracts** — a `workflow/skills/*.md` file that no adapter (Pi skill, Claude command, Codex prompt/skill) references and no doc declares shared-only: dead weight that still reads as canonical.
2. **Undeployed contracts** — a contract missing from `scripts/deploy-workflow`'s `FILES` list never reaches scaffolded projects; the "canonical contract" quietly stops being deployed. (All three current skills ARE in the list — the test keeps it that way.)
3. **Tracked duplicates** — `codex/workflow/ticket-template.md` is a byte-identical tracked copy of `workflow/ticket-template.md` (verified: same git blob hash `1fed2cb` at `1f89823`), deployed to `$CODEX_HOME/workflow/` by `scripts/deploy-codex`. Identical today; the first divergent edit to either copy forks the contract with no alarm.

One smoke test pins all three invariants, plus the Codex-home resolution check (deployed skills actually land under `$CODEX_HOME`) that `tests/codex-organization-smoke.sh` partially covers.

## Current state

- `workflow/skills/` — 3 files: `adversary.md` (45 lines), `implementation-loop.md` (45), `orchestration.md` (128).
- Reference surfaces to scan for mentions: `claude/commands/*.md`, `claude/CLAUDE.md`, `pi/skills/` (check it exists: `ls pi/skills/`), `pi/AGENTS.md`, `codex/**/*.md`, `workflow/spec.md`. Known references at `1f89823`: `workflow/spec.md:134` lists `workflow/skills/orchestration.md` as the orchestration contract; `claude/CLAUDE.md` Workflow section references `workflow/skills/orchestration.md`.
- `scripts/deploy-workflow:17-36` — `FILES=(...)` array of `source|dest` pairs; includes all three `workflow/skills/*.md` plus `workflow/{spec,memory,plan-archive,review-rubric,ticket-template,linear-ticket-template}.md` and the plan templates.
- `codex/workflow/` — 2 tracked files: `ticket-template.md` (duplicate of `workflow/ticket-template.md`) and `dynamic-workflow-triggers.md` (Codex-specific, no `workflow/` counterpart).
- `scripts/deploy-codex` — deploys the `codex/` tree to `$CODEX_HOME` (default `~/.codex`), `--codex-home DIR` override, `--dry-run` mode. `tests/codex-organization-smoke.sh:59-69` already asserts deployed files exist under a temp codex home (`assert_file "$CODEX_HOME_DIR/workflow/ticket-template.md"` etc.) — read that test first; it is the harness pattern to mirror, and possibly the file to EXTEND instead of creating a new one (decide in step 1).
- CI smoke list: `.github/workflows/agentic-infra.yml:33-45`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Blob-identity check | `git hash-object codex/workflow/ticket-template.md workflow/ticket-template.md` | two identical hashes |
| Existing codex smoke | `bash tests/codex-organization-smoke.sh` | exit 0 |
| New/extended smoke | `bash tests/workflow-contract-coverage-smoke.sh` (or the extended codex one) | exit 0 |
| YAML sanity | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/agentic-infra.yml'))"` | exit 0 |

## Scope

**In scope**:
- `tests/workflow-contract-coverage-smoke.sh` (new) — OR extend `tests/codex-organization-smoke.sh` for the duplicate check only if step 1 decides so; prefer the new file (coverage is a workflow concern, not a codex one).
- `.github/workflows/agentic-infra.yml` (add the smoke)
- `workflow/spec.md` — ONLY if step 2 finds an unreferenced contract that should be declared shared-only (one line).

**Out of scope**:
- Deduplicating `codex/workflow/ticket-template.md` by symlink/generation — deploy-codex's copy semantics are deliberate (Codex home is a deploy target); the invariant to enforce is identity, not single-copy.
- `scripts/deploy-workflow`, `scripts/deploy-codex` themselves.
- Fixing any orphan found — report it; deletion/reference is a maintainer call.

## Git workflow

- Branch: `advisor/014-contract-coverage`
- Commit: `test(workflow): pin contract coverage and duplicate identity`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Inventory and decide the harness shape

Read `tests/codex-organization-smoke.sh` fully. Confirm `pi/skills/` exists and list it. Build the reference inventory for each `workflow/skills/*.md`: `grep -rln "workflow/skills/<name>" claude/ pi/ codex/ workflow/spec.md`. Record results. Decision: new standalone `tests/workflow-contract-coverage-smoke.sh` (default) unless >50% of its assertions would duplicate the codex smoke's temp-home setup — in that case extend the codex smoke and name the addition clearly.

**Verify**: inventory recorded in your report (per-contract reference list).

### Step 2: Write the coverage assertions

In the new smoke (house style: `set -euo pipefail`, `ROOT_DIR` resolution, assert helpers):

1. **Referenced-or-declared**: for each `workflow/skills/*.md`, assert at least one reference among the adapter surfaces from step 1, OR the string `shared-only` appears on the line mentioning it in `workflow/spec.md`. If a contract fails both at baseline, STOP (report the orphan; the maintainer chooses reference vs declaration vs deletion).
2. **Deployed**: for each `workflow/skills/*.md`, assert its basename appears in `scripts/deploy-workflow`'s `FILES` array (`grep -F "workflow/skills/<name>|" scripts/deploy-workflow`).
3. **Duplicate identity**: assert `git hash-object codex/workflow/ticket-template.md workflow/ticket-template.md` produces two identical lines (compare with `sort -u | wc -l` → 1). Failure message must say which file to edit: "edit workflow/ticket-template.md (source of truth) and re-copy to codex/workflow/, or make them diverge deliberately by removing this assertion with a rationale".
4. **No new silent copies**: assert `codex/workflow/` contains ONLY the known files (`ticket-template.md`, `dynamic-workflow-triggers.md`) — a new copy of a `workflow/` contract under `codex/` must either be added to this allowlist with an identity assertion or rejected.
5. **Codex-home resolution**: run `scripts/deploy-codex --dry-run --codex-home "$(mktemp -d)"` and assert exit 0 (the deep file assertions stay in `tests/codex-organization-smoke.sh`; here only prove the entry point still resolves a custom home).

**Verify**: `bash tests/workflow-contract-coverage-smoke.sh` → exit 0.

### Step 3: CI wiring

Add the smoke to `.github/workflows/agentic-infra.yml` after `codex-organization-smoke`.

**Verify**: YAML sanity → exit 0; `bash tests/codex-organization-smoke.sh` still exits 0.

## Test plan

The smoke IS the test: 5 invariant classes. Negative-case spot check during development (not committed): temporarily append a byte to `codex/workflow/ticket-template.md` → assertion 3 must fail with the guidance message; revert.

## Done criteria

- [ ] `bash tests/workflow-contract-coverage-smoke.sh` exits 0
- [ ] Negative spot-check performed and reverted (`git status` clean of it; describe in report)
- [ ] Reference inventory in the report, one line per `workflow/skills/*.md`
- [ ] CI runs the new smoke; YAML parses
- [ ] `bash tests/codex-organization-smoke.sh` exits 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Step 1 finds a `workflow/skills/*.md` with zero references and no obvious shared-only rationale — report; do not delete, do not silently add a `shared-only` marker without maintainer sign-off.
- `codex/workflow/` contains files beyond the two known ones at baseline (layout drifted; the allowlist needs the maintainer).
- `deploy-codex --dry-run` writes anything to the temp dir or the real `~/.codex` (dry-run not dry — report as a bug finding).

## Maintenance notes

- Adding a shared contract now has a checklist enforced by CI: reference it from ≥1 adapter (or declare shared-only), add it to `deploy-workflow` FILES, and never copy it under `codex/` without an identity assertion.
- If `codex/workflow/ticket-template.md` must legitimately diverge one day, delete assertion 3 in the same PR with the rationale in the commit — the assertion's failure message says so.
- Interaction with plan 009: `deploy-workflow --check` covers deployed-project drift; this plan covers in-repo contract drift. Together they close the loop source → repo copies → deployed projects.
