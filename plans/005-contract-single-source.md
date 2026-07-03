# Plan 005: Make workflow/spec.md the single accurate routing contract (spec-guide row, adapter column, manual-only commands)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 1f89823..HEAD -- workflow/spec.md claude/CLAUDE.md claude/commands/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Check `plans/README.md`: if plan 001
> is DONE, `spec-guide` exists on both adapters (adjust step 1 wording
> accordingly); if plan 003 is DONE, `claude/CLAUDE.md` is already slimmed
> (apply step 3 to the slimmed file).

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (composes with 001 and 003; see drift check)
- **Category**: docs
- **Planned at**: commit `1f89823`, 2026-07-03

## Why this matters

`workflow/spec.md` declares itself the canonical workflow contract, but it is incomplete and partially wrong, and the routing mapping is duplicated across five surfaces (spec.md table, spec.md "Default commands" lists, `claude/CLAUDE.md` routing bullets, and the two code classifiers). Concretely: the live `spec-guide` route (emitted by `claude/hooks/workflow-router-lib.mjs:289-300`, command file `claude/commands/spec-guide.md` exists) appears nowhere in spec.md or CLAUDE.md; the `tasks-till-done` row reads as harness-neutral but is Pi-only; and 11 of the 30 Claude command files are absent from the contract entirely, so nobody can tell intentional-manual-only from drift. Every future route change currently requires up to five synchronized edits. This plan makes spec.md accurate and complete, marks adapter-specific rows, and reduces the CLAUDE.md duplication to a pointer.

## Current state

- `workflow/spec.md:102-123` — "Routing rules" table, 18 rows. No `spec-guide` row. Last row: `| Task tools active and actionable request | tasks-till-done assists selected route | TaskList | all tasks done, blocked, stalled, or limit |` — implemented only by `pi/extensions/tasks-till-done.ts` (the Claude router has no such route; `buildRouteContext` in `workflow-router-lib.mjs:364` explicitly says "Task* tools are Pi-only").
- `workflow/spec.md:147-182` — "Default commands": 14 Pi skills, 15 Claude commands listed.
- Actual Claude command files (`ls claude/commands/`): 30 files. Present in spec.md lists: `plan-loop`, `plan-implement`, `adversary`, `implement`, `review`, `verify-workflow`, `bug-check`, `linear-ticket-create`, `linear-work`, `pr-review`, `pr-qa`, `sec-pr`, `ci-fix`, `github-pr-review`, plus `/plan` (file is `plan-create.md`). ABSENT from spec.md: `spec-guide`, `spec-verify`, `commit`, `cross-repo-audit`, `linear-project-setup`, `qa-planner`, `qa-generator`, `qa-healer`, `qa-reviewer`, `qa-failure-dossier` (and note `plan-create.md` is listed as `/plan`).
- `claude/CLAUDE.md` "## Workflow" section — 14 routing bullets re-listing the same trigger→command mapping as spec.md's table.
- Router emits `spec-guide` on Claude at `1f89823` (probe: `node -e 'import("./claude/hooks/workflow-router-lib.mjs").then(m => console.log(m.classifyWorkflowRoute("rédige une nouvelle spec").route))'` → `spec-guide`); Pi lacks it until plan 001 lands.
- Doc invariants are enforced by `bash tests/workflow-docs-smoke.sh` (29KB — read the parts that assert spec.md/CLAUDE.md content before editing) and `bash tests/claude-skills-smoke.sh`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Docs smoke | `bash tests/workflow-docs-smoke.sh` | exit 0 |
| Claude skills smoke | `bash tests/claude-skills-smoke.sh` | exit 0 |
| Claude hooks smoke | `bash tests/claude-hooks-smoke.sh` | exit 0 |
| Command inventory | `ls claude/commands/ \| sed 's/\.md$//' \| sort` | 30 names |

## Scope

**In scope**:
- `workflow/spec.md`
- `claude/CLAUDE.md` (Workflow section only)
- `tests/workflow-docs-smoke.sh` — ONLY if it asserts spec.md/CLAUDE.md content that must evolve with this change; mirror the existing assertion style.

**Out of scope**:
- The classifiers (`claude/hooks/`, `pi/extensions/`) — no behavior change here.
- The 30 command files themselves — no deletion or edit; if you believe a qa-* command is dead, note it in the report, do not remove it.
- `pi/AGENTS.md`, `workflow/skills/*`, scaffold templates.

## Git workflow

- Branch: `advisor/005-contract-single-source`
- Commit: `docs(workflow): complete spec.md routing contract and de-duplicate CLAUDE.md routing`
- Do NOT push unless the operator asked.

## Steps

### Step 1: Add the `spec-guide` row and an adapter marker to the routing table

In `workflow/spec.md` "Routing rules" table:
- Add after the `plan-loop` row: `| Guided spec construction ("rédige une spec", "guide-moi pour la spec") | spec-guide | spec drafted via /spec template | spec solid, hands off to /spec |`
- Add a short paragraph immediately under the table:

```markdown
Adapter coverage: all routes are shared by the Pi extension router and the
Claude hook router, except `tasks-till-done` (Pi-only Task* runtime) and
`spec-guide` (Claude-only until the Pi port lands). The executable source of
truth for classification is `claude/hooks/workflow-router-lib.mjs` and
`pi/extensions/lib/workflow-router-runtime.ts`; this table documents intent,
the code decides.
```

If plan 001 is DONE, write "except `tasks-till-done` (Pi-only Task* runtime)" only.

**Verify**: `grep -c "spec-guide" workflow/spec.md` ≥ 2.

### Step 2: Add a "Manual-only commands" subsection

In `workflow/spec.md`, after the "Default commands" Claude list, add:

```markdown
Manual-only Claude commands (invoked by explicit slash only, never ambiently
routed): `/spec-verify`, `/commit`, `/cross-repo-audit`,
`/linear-project-setup`, and the Playwright QA chain `/qa-planner`,
`/qa-generator`, `/qa-healer`, `/qa-reviewer`, `/qa-failure-dossier`.
`/spec-guide` is routed ambiently (see routing table). `/plan` maps to
`claude/commands/plan-create.md`.
```

Cross-check the list against `ls claude/commands/` — every file must now be accounted for either in "Default commands", this manual-only list, or the routing table.

**Verify**: for each of the 30 names from `ls claude/commands/ | sed 's/\.md$//'`, `grep -q "<name>" workflow/spec.md` succeeds (write a small shell loop; `plan-create` counts via the `/plan` mapping sentence).

### Step 3: Replace CLAUDE.md routing bullets with a pointer

In `claude/CLAUDE.md` "## Workflow", delete the 14 trigger→command bullets (the block starting "Route requests through the smallest Etabli workflow..." through the ops-stop bullet) and replace with:

```markdown
- Route requests per the routing table in `workflow/spec.md`; the router hook
  injects the selected route. Destructive/secret/production/deploy work stops
  with a risk brief and waits for user approval.
```

Keep every other Workflow bullet (PLAN.md rules, TDD, archive rules, /goal, etc.) untouched.

**Verify**: `grep -c "linear-ticket-create" claude/CLAUDE.md` → 0; the ops-stop safety sentence still present (`grep -c "risk brief" claude/CLAUDE.md` → 1).

### Step 4: Run the doc smoke suite and reconcile assertions

`bash tests/workflow-docs-smoke.sh` — if it fails on an assertion that hard-codes the old CLAUDE.md bullets or the old spec.md table shape, update THAT assertion minimally to match the new content (mirror existing style). If it fails for any other reason, STOP.

**Verify**: `bash tests/workflow-docs-smoke.sh && bash tests/claude-skills-smoke.sh && bash tests/claude-hooks-smoke.sh` → all exit 0.

## Test plan

- The doc smoke scripts are the tests. Add one new assertion to `tests/workflow-docs-smoke.sh` (matching its existing assertion style): spec.md must contain `spec-guide` — this prevents the route from silently vanishing from the contract again.
- Verification: all three smoke scripts exit 0.

## Done criteria

- [ ] Routing table has the `spec-guide` row and the adapter-coverage paragraph
- [ ] The 30-command accountability loop from step 2 passes
- [ ] CLAUDE.md routing bullets replaced by the pointer; safety sentence retained
- [ ] `bash tests/workflow-docs-smoke.sh` exits 0 (with the new spec-guide assertion added)
- [ ] `bash tests/claude-skills-smoke.sh` and `bash tests/claude-hooks-smoke.sh` exit 0
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

- `tests/workflow-docs-smoke.sh` fails for a reason other than the two anticipated assertion classes (CLAUDE.md bullets, spec.md table shape).
- You find a command file that is neither routable nor plausibly manual-only (e.g. appears orphaned/dead) — report it; deletion is out of scope.
- `claude/CLAUDE.md` at HEAD no longer contains the routing bullets (plan 003 or the operator already removed them) — skip step 3, note it.

## Maintenance notes

- New rule this plan establishes: a route exists when it is in BOTH classifiers + the spec.md table; a command exists when it is in a spec.md list. Reviewer should reject future PRs adding one without the others.
- The `Verdict:`-prefix and command/skill naming differences between adapters remain documented only in plan 001's test normalizer; if a third harness adapter ever appears, promote that mapping into spec.md.
