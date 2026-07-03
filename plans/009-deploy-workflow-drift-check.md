# Plan 009: Give deploy-workflow a --check mode that reports drift between templates and deployed copies

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- scripts/deploy-workflow tests/workflow-scaffold-smoke.sh tests/deploy-agent-workflow-smoke.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

`scripts/deploy-workflow` copies the workflow contract (18 files: scaffold templates, `workflow/*.md`, plan templates) into target projects with `cp`. Copies are correct here — target projects may legitimately customize them — but there is no way to see when a deployed project has fallen behind the source templates (or diverged locally). Hooks and settings are symlinked by the sibling scripts (`deploy-agent-workflow`, `install.sh`) and cannot drift; the templates silently fossilize. A read-only `--check` mode makes drift visible without changing deploy semantics.

## Current state

`scripts/deploy-workflow` (bash, `set -euo pipefail`):

- Lines 17-36 — `FILES=(...)`: 18 `source|destination` pairs, e.g. `"$REPO_DIR/workflow/spec.md|workflow/spec.md"`.
- Lines ~40-56 — `usage()` documenting `[target-dir] [--dry-run] [--force]`.
- Lines ~235-247 — the copy: existing destination gets a timestamped backup (`mv` to `backup_path`), then `cp "$source_path" "$destination_path"`; counters `WRITTEN`/`UNCHANGED`/`CONFLICTS`; `status_line` helper prints aligned status labels.
- Existing behavior worth reusing: the script already distinguishes unchanged files (it has an `UNCHANGED` counter) — read the full script before editing to see how it compares (likely `cmp`-based); mirror that mechanism.
- Tests: `bash tests/workflow-scaffold-smoke.sh` exercises deploys into temp dirs — read it to see the assertion style; extend it for `--check`.

Conventions: bash with `set -euo pipefail`, `status_line LABEL path` output style, shellcheck-clean-ish (CI runs `bash -n` only).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Syntax | `bash -n scripts/deploy-workflow` | exit 0 |
| Scaffold smoke | `bash tests/workflow-scaffold-smoke.sh` | exit 0 |
| Manual check run | `scripts/deploy-workflow /tmp/dw-check-demo --check` | see step 2 |

## Scope

**In scope**:
- `scripts/deploy-workflow`
- `tests/workflow-scaffold-smoke.sh` (add `--check` cases)

**Out of scope**:
- Switching templates to symlinks (rejected: deployed projects legitimately edit their copies; symlinks would propagate edits both ways and break customization).
- `scripts/deploy-agent-workflow`, `scripts/install.sh`, `scripts/scaffold-project`.
- Auto-updating drifted files (that is `--force`'s existing job).

## Git workflow

- Branch: `advisor/009-deploy-workflow-check`
- Commit: `feat(scripts): add deploy-workflow --check drift report`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Add the `--check` flag

In the argument loop, add `--check) CHECK=1 ;;` (default `CHECK=0`) and document it in `usage()`: "Report drift between source templates and deployed files without writing".

### Step 2: Implement the check pass

When `CHECK=1`, instead of deploying, iterate `FILES` and for each pair print one `status_line`:
- destination missing → `MISSING <relative_path>`
- byte-identical → `OK <relative_path>`
- differs → `DRIFT <relative_path>`

Count `DRIFT + MISSING`; print a one-line summary (`N drifted, M missing, K ok`); exit 1 if `DRIFT + MISSING > 0`, else 0. `--check` must not create, back up, move, or write anything (guard it before any `mkdir`/`mv`/`cp`), and must compose with neither `--dry-run` nor `--force` (error out if combined: "flags are mutually exclusive").

**Verify**:
```
d=$(mktemp -d) && scripts/deploy-workflow "$d" && scripts/deploy-workflow "$d" --check; echo "exit=$?"
```
→ all `OK`, `exit=0`. Then `echo x >> "$d/workflow/spec.md" && rm "$d/PLAN_TEMPLATE.md" && scripts/deploy-workflow "$d" --check; echo "exit=$?"` → one `DRIFT`, one `MISSING`, `exit=1`, and `ls "$d"` unchanged by the check itself.

### Step 3: Extend the smoke test

Add to `tests/workflow-scaffold-smoke.sh` (matching its existing temp-dir + assertion style): fresh deploy → `--check` exits 0; mutate one file + delete one → `--check` exits 1 and output contains `DRIFT` and `MISSING`; `--check --force` errors.

**Verify**: `bash tests/workflow-scaffold-smoke.sh` → exit 0.

## Test plan

- Smoke additions from step 3 (clean / drifted / missing / flag-conflict).
- `bash -n scripts/deploy-workflow` → exit 0 (CI covers this after plan 007 also covers tests/).

## Done criteria

- [ ] `--check` documented in `usage()` and README-style help output
- [ ] Clean-deploy check exits 0; drifted check exits 1 with `DRIFT`/`MISSING` lines; no filesystem writes in check mode
- [ ] `bash tests/workflow-scaffold-smoke.sh` exits 0
- [ ] `bash -n scripts/deploy-workflow` exits 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- The existing script's comparison mechanism (UNCHANGED counter) turns out to be timestamp-based rather than content-based — report; the check must be content-based (`cmp -s`).
- `tests/workflow-scaffold-smoke.sh` structure makes adding cases require refactoring the harness — report instead of refactoring.

## Maintenance notes

- Adding a file to `FILES` automatically includes it in `--check`; no second list to maintain.
- Future option (deferred): a `--check --json` output for automation once something consumes it. YAGNI now.
