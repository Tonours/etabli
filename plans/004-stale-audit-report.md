# Plan 004: Mark the workflow-router audit report as not-landed so it stops being cited as ground truth

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- .workflow/ tests/fixtures/claude-hooks/` — note `.workflow/` is gitignored, so also run `ls .workflow/workflow-router-audit/` and confirm `final-report.md` still exists. If the directory is gone, mark this plan REJECTED in `plans/README.md` (problem solved) and stop.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

`.workflow/workflow-router-audit/final-report.md` presents itself as the completed outcome of a router audit and lists "Accepted Results" including: "Added a first-class `dynamic-workflow` route", "Added `$skill` no-injection behavior", "Updated `workflow/spec.md` with the `dynamic-workflow` route". None of these exist in the source tree: `grep -rn "dynamic-workflow\|DYNAMIC_WORKFLOW" claude/hooks/ pi/extensions/ workflow/spec.md` returns nothing at `1f89823`. The report is actively misleading: this repo's own convention is that agents read prior audit artifacts to avoid re-reporting fixed items, so a false "fixed" claim makes real gaps invisible. This plan annotates the report as not-landed and records the disposition of each claimed-but-absent change. It deliberately does NOT implement the missing `dynamic-workflow`/`$skill` routes — that is a product decision recorded as rejected-for-now in `plans/README.md`.

## Current state

- `.workflow/workflow-router-audit/final-report.md` — the report. Lines 14-23 are the "Accepted Results" list with the false claims. The directory is local-only (gitignored — see `.gitignore` and commit `be2b822 chore(workflow): untrack local workflow artifacts`).
- Claims verified TRUE (leave them alone): the `github-pr-review` alias exists (`claude/commands/github-pr-review.md`), `claude/README.md` coverage landed.
- Claims verified FALSE at `1f89823` (no trace in source or `git log -S`):
  - `dynamic-workflow` route + `DYNAMIC_WORKFLOW_PATTERN` (both classifiers, spec.md)
  - `$skill` no-injection behavior
  - "Prioritized general review before general verify" (in `claude/hooks/workflow-router-lib.mjs`, `VERIFY_PATTERN` at line 173 is still checked before `REVIEW_PATTERN` at line 209)
  - "ambiguous short-continuation guard for isolated `relance`" (no `relance`-specific guard in the classifier; `relance` appears only inside `IMPLEMENT_PATTERN` as a verb)
- Related fixtures DO exist and are green in CI (they assert current, non-dynamic-workflow behavior): `tests/fixtures/claude-hooks/router-dynamic-workflow.json` (prompt: "Utilise un dynamic workflow avec subagents pour auditer le router"), `router-dollar-skill.json`, `router-short-relance.json`, `router-review-with-evidence.json`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Confirm absence | `grep -rn "dynamic-workflow" claude/hooks pi/extensions workflow/spec.md` | no matches |
| Fixture behavior | `bash tests/claude-hooks-smoke.sh` | exit 0 |

## Scope

**In scope**:
- `.workflow/workflow-router-audit/final-report.md` (prepend a banner)
- `.workflow/workflow-router-audit/results/router-workflow-review.md` (same banner)

**Out of scope**:
- Implementing `dynamic-workflow`, `$skill` no-injection, review/verify reordering, or the `relance` guard — explicitly rejected for now; see `plans/README.md`.
- Deleting the audit directory — it contains reusable tooling (`tools/conversation-audit.mjs`) the report's own "Reusable Follow-up" section wants kept.
- `tests/fixtures/claude-hooks/` — the fixtures assert real current behavior; keep them.

## Git workflow

- `.workflow/` is gitignored: these edits produce no commit. Nothing to branch or push. Record the edit in your final report instead.

## Steps

### Step 1: Prepend a status banner to both report files

At the very top of `.workflow/workflow-router-audit/final-report.md` and `.workflow/workflow-router-audit/results/router-workflow-review.md`, insert:

```markdown
> **STATUS: NOT LANDED (verified 2026-07-03 at commit 1f89823).**
> The "Accepted Results" below describe patches that were prepared during the
> audit but never applied to the source tree. Absent from source:
> `dynamic-workflow` route, `DYNAMIC_WORKFLOW_PATTERN`, `$skill` no-injection,
> review-before-verify reordering, isolated-`relance` guard, and the
> corresponding `workflow/spec.md` row. Landed for real: `github-pr-review`
> alias, `claude/README.md` coverage, the `tests/fixtures/claude-hooks/`
> fixtures (which assert CURRENT behavior, not the unlanded routes).
> Do not treat this report as ground truth for router behavior; read
> `claude/hooks/workflow-router-lib.mjs` directly.
```

**Verify**: `head -12 .workflow/workflow-router-audit/final-report.md` → banner present.

### Step 2: Confirm nothing else references the report as authoritative

`grep -rn "workflow-router-audit" --include="*.md" workflow/ claude/ docs/ AGENTS.md README.md` → if any tracked doc cites the audit's results as applied, list those citations in your report (do not edit tracked files in this plan).

**Verify**: grep output captured; zero tracked-doc citations expected.

## Test plan

None (untracked local docs only). `bash tests/claude-hooks-smoke.sh` must still pass untouched (run it once to prove no accidental edits).

## Done criteria

- [ ] Banner present at top of both files (`head -12` output in report)
- [ ] `grep -rn "dynamic-workflow" claude/hooks pi/extensions workflow/spec.md` still empty (you changed no source)
- [ ] `bash tests/claude-hooks-smoke.sh` exits 0
- [ ] `git status` shows no tracked-file modifications from this plan
- [ ] `plans/README.md` status row updated

## STOP conditions

- The directory `.workflow/workflow-router-audit/` does not exist → mark plan REJECTED (already cleaned), stop.
- You find `dynamic-workflow` HAS landed since `1f89823` → the banner would be wrong; report instead.
- A tracked doc cites the audit results as applied → report the locations; fixing them may belong in plan 005's contract cleanup.

## Maintenance notes

- If the operator later wants `dynamic-workflow` routing for real, that is a new plan: add the pattern + route to BOTH classifiers (plans 001/002 conventions), a spec.md row (plan 005 conventions), and repurpose the existing fixtures.
- The underlying process gap — an audit that writes "Accepted Results" before its patches land — is worth a one-line rule in `workflow/spec.md` ("reports record applied state only, verified by grep"); deferred to plan 005's scope decision.
