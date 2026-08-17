# Implemented: multi-repo plan semantics documented, stale/gate-invisible plans surfaced

## Metadata
- Archived: 2026-08-17
- Source plan: `PLAN.md` — Define multi-repo PLAN.md semantics — one owner plan, satellite repos, archive completeness
- Source plan SHA-256: `ab9225497a5436688700d339d4c35bd04719c2cf9399520fbe2d706befe8acd8`
- Status: IMPLEMENTED
- Commit / branch: `main`

## Outcome
- `scripts/plan-cleanup --status`: read-only mode reporting a root plan's status,
  whether the router can actually read that status, `Last revised` age, and
  staleness. Exits non-zero on stale, router-invisible, or future-dated plans.
  Never writes, never deletes.
- `workflow/plan-archive.md`: new "Stale Plans" and "Multi-Repo Plans" sections;
  the Archive Format template now matches what the script enforces.
- `workflow/spec.md`: one pointer to both rules.
- `PLAN_TEMPLATE*.md`: optional `## Repos` block (documentation; nothing parses it).
- `tests/plan-cleanup-smoke.sh`: 12 new `--status` cases plus a regression guard
  that `--archive` / `--discard` still reject extra arguments.

## Context
- The question that started this: does a plan spanning 2+ repos get duplicated per
  repo? Answer: no. `scripts/plan-cleanup:31-33` resolves plan, archive, and
  `docs/plan/` root from one `cwd`, and `:46,50-53` binds the archive to the plan by
  SHA-256 of its exact bytes. One repo, one plan, one archive.
- `claude/hooks/workflow-router-lib.mjs:397-400` matches only
  `- Status: DRAFT|CHALLENGED|READY` anchored to the full line. Anything else
  becomes `unknown`, which allows ordinary work — so a decorated or missing status
  silently disables the READY gate.
- `scripts/deploy-workflow:30,35-37` copies the contract, templates, and
  `plan-cleanup` per project (`:298` is `cp`), so changes reach a project only on
  redeploy.

## Decisions
### One owner plan with declared satellites, not a plan per repo
- Context: multi-repo work had no defined model; the contract never mentioned repos.
- Choice: exactly one owner repo holds root `PLAN.md` and the single archive; other
  repos are declared satellites; the archive is never duplicated.
- Rejected options: duplicating `PLAN.md` per repo (the SHA-256 binding makes
  byte-identical copies a maintenance trap, and two root plans mean two independent
  READY gates that cannot see each other); one shared archive written to several
  repos (no single source of truth once one copy is edited).
- Rationale: matches what agents already do by hand — the `browser-extension` plan
  carried a repo/branch table and cross-repo PR coupling before any contract said to.
- Consequences: enforcement is prose only, because a machine check would have to
  read outside its own repo. The owner-selection rule is therefore written to be
  decidable by a reader.

### Retargeted from multi-repo archiving to abandoned plans
- Context: the plan originally claimed a satellite-completeness check would catch the
  observed failure — a stale plan sitting in the other repo.
- Choice: fix abandoned/gate-invisible plans mechanically; document multi-repo only.
- Rejected options: shipping the satellite parser as designed.
- Rationale: the adversary pass showed the stale plan was *unrelated* work, so a
  satellite check would have passed while the plan sat there. Surveying `~/work`
  then showed the real problem is systemic and repo-agnostic.
- Consequences: the delivered check targets a failure with evidence in seven repos
  rather than a hypothesised one.

### No satellite-completeness parser
- Context: the original design parsed a `## Repos` block and required each satellite
  to appear in the archive with a terminal state.
- Choice: dropped. The block stays as documentation.
- Rejected options: shipping it fence-aware and fail-closed.
- Rationale: both adversary reviewers found it fails open on a malformed block, and
  one found it would parse the fenced *examples* in the plan's own body as real
  declarations — refusing that plan's own archive. It also targeted an unobserved
  failure and would be inert until redeploy.
- Consequences: multi-repo completeness rests on the written contract. Revisit only
  after a real miss.

### Status parsing must mirror the router exactly
- Context: the first implementation used a lenient parser (split on whitespace/dash).
- Choice: reuse the router's exact anchored regex; a `Status:` line it cannot match
  is `invalid`, and no line at all is `missing-status`. Both exit non-zero.
- Rejected options: keeping the lenient parser for friendliness.
- Rationale: a tool that reports a gate-invisible plan as healthy defeats its own
  purpose. This immediately corrected a real misreport.
- Consequences: `gateVisible` is part of the output contract.

## Accepted Drift
- Original plan/spec: acceptance criteria described a satellite-completeness check
  in `--archive`.
- Implemented reality: no such check; `--archive` is untouched. A new read-only
  `--status` mode addresses the observed failure instead.
- Why accepted: recorded in Decision Log and Review Changes during the adversary
  pass, before implementation started.

## Validation Evidence
- command: `bash tests/plan-cleanup-smoke.sh`
  - result: `plan-cleanup smoke test: ok`. Mutation-checked — neutering the exit code
    failed with `--status accepted a stale READY plan`.
- command: `bash tests/workflow-docs-smoke.sh`
  - result: `workflow docs smoke test: ok`
- command: `scripts/verify-agentic-infra core`
  - result: exit 0, 27 PASS, 0 failures
- command: `--status` across all `~/work/*/PLAN.md`
  - result: 7 flagged, 4 clean. Stale: `forestadmin` 138d, `forestadmin-poc` 47d.
    Router-invisible: `claude-repo` (`READY — all 6 slices IMPLEMENTED + validated`),
    `forestadmin-bugfixes` (`DONE`), and three plans with no `Status:` line
    (`Gc-feature-workflow-editor-palet`, `forest-express-sequelize`, `pi-read`).
    Every target repo's `PLAN.md` left intact.
- command: manual — documented Archive Format written into a fixture, then `--archive`
  - result: exit 0, plan removed. Proves the template in `plan-archive.md` is one the
    script accepts; the prior doc/script drift is closed.

## Follow-up State
- Remaining risks: the 30-day threshold is arbitrary (overridable via
  `--max-age-days`, and surfacing only — nothing gates on it). Multi-repo rules are
  prose-enforced by design. Everything in `plan-cleanup` is inert in a project until
  `deploy-workflow` runs there again.
- Parking lot: seven flagged plans need the user's archive-vs-discard decision, one
  repo at a time. Whether `--status` should later become a real gate in
  `verify-agentic-infra` — decide after those seven are resolved so the gate does not
  land red. Cross-repo gating would need its own ADR (a guard trusting paths outside
  its repo is a security surface).
- Superseded docs/specs: none.
- Next links: an ADR is likely warranted, since this defines repo-level workflow
  semantics.

## Adversary And Review Provenance
- Plan adversary: `same-family-pass: double-sample` — two fresh-context Claude
  `reviewer` subagents, independent contexts, distinct lenses (correctness/citations
  → GO WITH NOTES; design/scope → BLOCK). Not a cross-model pass: this machine
  disables non-Claude runners (`~/.claude/rules/claude-only-agents.md`).
- Implementation review: one fresh-context Claude `reviewer` subagent on the diff →
  GO WITH NOTES. Its HIGH (parser leniency) was accepted and fixed before commit.
