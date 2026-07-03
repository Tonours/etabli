# Plan 007: Speed up and tighten CI — dependency caching, per-test attribution, full bash syntax coverage

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- .github/workflows/agentic-infra.yml tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

The single CI workflow (`.github/workflows/agentic-infra.yml`) has three cheap gaps: (1) no dependency caching — `bun install --frozen-lockfile` and `npm install --global hunkdiff` run cold on every push/PR; (2) the 10 shell smoke tests plus `validate-adrs` run inside ONE `run:` block, so a failure reports as "Run script tests failed" without naming the test, and everything after the failure never runs (`bash` in GitHub steps uses `-e`), hiding additional failures; (3) the `bash -n` syntax check only walks `scripts/`, so the 5 test files not executed by CI (`workflow-real-agent-scenarios.sh`, `adr-skill-e2e.sh`, `adr-skill-stress.sh`, `deploy-agent-workflow-smoke.sh`, `workflow-autonomous-plan-loop-smoke.sh`) get zero validation and can rot with parse errors.

## Current state

`.github/workflows/agentic-infra.yml` (120 lines, 3 jobs):

- Lines 19-25 — syntax check limited to `scripts/`:

```yaml
      - name: Bash syntax check
        run: |
          while IFS= read -r -d '' file; do
            if head -n 1 "$file" | grep -Eq '^#!.*\b(bash|sh)\b'; then
              bash -n "$file"
            fi
          done < <(find scripts -maxdepth 1 -type f -print0)
```

- Lines 33-45 — one block, 11 serial invocations (`codex-organization-smoke`, `workflow-docs-smoke`, `workflow-scaffold-smoke`, `claude-hooks-smoke`, `claude-skills-smoke`, `workflow-cli-smoke`, `adr-hook-smoke`, `adr-validate-smoke`, `adr-validation-golden`, `adr-helper-smoke`, `node scripts/validate-adrs`).
- Lines 47-89 — `verify-pi-typescript`: `oven-sh/setup-bun@v2` (no cache config), `bun install --frozen-lockfile` in `pi/`, bun test, `bun run verify:skills`, import smoke.
- Lines 91-119 — `verify-neovim-smoke`: setup-bun again, `npm install --global hunkdiff` (uncached), 3 smoke tests.
- Lockfile: check whether `pi/bun.lock` or `pi/bun.lockb` exists (`ls pi/bun.lock*`) — the cache key in step 2 must reference the real file.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Workflow YAML sanity | `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/agentic-infra.yml'))"` | exit 0 |
| Local run of any smoke | `bash tests/<name>.sh` | exit 0 |
| Syntax loop locally | see step 1 verify | exit 0 |

## Scope

**In scope**:
- `.github/workflows/agentic-infra.yml`

**Out of scope**:
- The test scripts themselves (no fixing tests here — if one fails locally at baseline, STOP).
- Wiring `workflow-real-agent-scenarios.sh` into a scheduled job (spawns real agent CLIs + network; recorded as deferred in `plans/README.md`).
- Any other workflow file (none exist today).

## Git workflow

- Branch: `advisor/007-ci-cache-matrix`
- Commit: `ci(infra): cache deps, attribute smoke tests, syntax-check tests dir`
- Do NOT push unless the operator asked (note: CI only proves itself on push/PR — say so in the handoff).

## Steps

### Step 1: Extend the syntax check to `tests/`

Change the `find` in the "Bash syntax check" step to walk both directories:

```yaml
          done < <(find scripts tests -maxdepth 1 -type f -print0)
```

**Verify locally**: run the loop body verbatim in the repo root → exit 0 (all current scripts and tests parse; if one fails, STOP — pre-existing breakage).

### Step 2: Split the smoke tests into named steps

Replace the single "Run script tests" block with one step per test, same order, e.g.:

```yaml
      - name: codex-organization-smoke
        run: bash tests/codex-organization-smoke.sh
      - name: workflow-docs-smoke
        run: bash tests/workflow-docs-smoke.sh
```

…through all 10 `bash tests/*.sh` plus a final `validate-adrs` step running `node scripts/validate-adrs`. Add `if: ${{ !cancelled() }}` on each of these steps so a failure in one still runs the rest (full failure attribution in one CI run). Named steps beat a matrix here: 11 ubuntu VMs for sub-second scripts would cost more spin-up than they parallelize (the suite is dominated by per-job setup, not test runtime).

**Verify**: YAML sanity command → exit 0.

### Step 3: Cache Bun dependencies

`oven-sh/setup-bun@v2` does not cache the install store. In `verify-pi-typescript`, add after checkout (adjust the lockfile name to what `ls pi/bun.lock*` showed):

```yaml
      - name: Cache bun install
        uses: actions/cache@v4
        with:
          path: ~/.bun/install/cache
          key: bun-${{ runner.os }}-${{ hashFiles('pi/bun.lock*') }}
```

### Step 4: Cache the hunkdiff global install

In `verify-neovim-smoke`, wrap the npm global install:

```yaml
      - name: Cache npm global
        uses: actions/cache@v4
        with:
          path: ~/.npm
          key: npm-global-hunkdiff-${{ runner.os }}
      - name: Install Hunk CLI
        run: npm install --global hunkdiff
```

(`~/.npm` caches the package tarballs; the install step stays but becomes a fast cache hit.)

**Verify (steps 2-4 together)**: YAML sanity command → exit 0; `grep -c "actions/cache@v4" .github/workflows/agentic-infra.yml` → 2.

### Step 5: Local dry-run of everything CI will run

Run the full CI-equivalent locally to prove no test was orphaned by the split: each of the 10 `bash tests/*.sh` + `node scripts/validate-adrs` → all exit 0. Diff the list of `bash tests/...` invocations in the new YAML against the old block — must be identical, order preserved.

**Verify**: all 11 commands exit 0; invocation diff empty.

## Test plan

- CI is the test. Locally: YAML parse + the 11 commands + syntax loop.
- After merge, the operator should confirm on the first push: per-test step names visible, cache steps report a save on run 1 / hit on run 2.

## Done criteria

- [ ] `find scripts tests` in the syntax-check step
- [ ] 11 named steps replace the single block, each with `if: ${{ !cancelled() }}`, same commands, same order
- [ ] Two `actions/cache@v4` steps (bun store, npm tarballs) with lockfile-keyed / static keys
- [ ] YAML sanity command exits 0
- [ ] All 11 test commands pass locally
- [ ] Only `.github/workflows/agentic-infra.yml` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- Any test script fails `bash -n` or fails when run locally at baseline (pre-existing breakage — report, don't fix here).
- `pi/` has no lockfile at all (cache key impossible — report; the install may not be frozen-lockfile-safe either).
- You are tempted to change what CI runs (add/remove a test): out of scope, report instead.

## Maintenance notes

- New smoke tests must be added as a named step (the split makes forgetting visible — CI shows the test list).
- `workflow-real-agent-scenarios.sh` remains unexecuted by CI by design (real agent spawns); its `bash -n` coverage now exists. A nightly `workflow_dispatch` job for it is a deliberate future decision.
- If the suite grows past ~2 min total, revisit the no-matrix decision.
