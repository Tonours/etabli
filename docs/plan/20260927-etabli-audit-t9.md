# Implemented: T9 audit — check runner runs every declared check, dead code removed, token-bench benchmark and skill audit, best-practices report

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — T9 audit Etabli — runner de checks réparé, code mort retiré, benchmark token-efficiency, audit bonnes pratiques
- Source plan SHA-256: `0f595ebfd6af0ead8aef28ebd0136e28b5fc658f8ecbd9aea32334aa6d54fad1`
- Status: IMPLEMENTED
- Commit / branch: not committed (worktree on `main` at `4d6fd5e`, alongside the parked T4 diff)
- Workflow initiative: `etabli-audit-t9` (blocked after F1, budget spent), `etabli-audit-t9-review` (review run authorized by the user, completed)

## Outcome
- `scripts/verify-agentic-infra` gives child checks `/dev/null` as stdin. Before the fix, `tests/guards-active-smoke.sh` consumed the manifest stream, and `full` ran 46 of 80 declared checks while printing `46/46`. Now every declared check runs: full 81/81, core 27/27, shell-docs 75/75, pi 6/6.
- Dead code removed:
  - `tests/fixtures/review-{cost,guidance,priority,spec-drift}/`;
  - `workflow/self-improvement/manifests/core-v{1,2}.json`;
  - `docs/jev-{claim,review}-pilot-20260922.json`;
  - `tests/fixtures/jev-plan-implement/` (untracked).
- New `scripts/token-bench`:
  - offline per-route cost estimate, with a baseline `--check` (3 % tolerance);
  - `--live` observed estimate from `claude -p "/context"`, free and never a gate;
  - `--skills` audit of every SKILL.md against the published Anthropic and Claude Code limits.
- Wiring: covered by `tests/token-bench-smoke.sh` (full profile); baseline in `workflow/runtime/token-bench-baseline.json`.
- Audit report: `docs/research/20260927-harness-practices-audit.md`.

## Context
- `workflow/runtime/agentic-infra-checks.tsv`: 27 core + 53 full rows; the runner's `while read` loop fed background children from the same stream.
- `claude -p "/context" --output-format json` reports `total_cost_usd: 0` and a per-category token table. No tokenizer or API key is available locally.
- Skills: 96 paths, 95 distinct skills (`pi/skills/herdr` is a symlink), 0 hard violations, 20 warnings. The warnings: `project-hunt` is about 6.3 k tokens; `design` nests references two levels deep; 12 long references have no contents heading.

## Decisions
### Fix the runner, not the offending smoke
- Context: any stdin-reading target truncates the manifest loop.
- Choice: `</dev/null` on the spawned child, plus a hermetic regression (serialized copy of the runner, stdin-eating target, red target).
- Rejected options: patching `guards-active-smoke.sh` only; adding a launched-count guard (the test already covers it).
- Rationale: protects every future target.
- Consequences: CI groups also run in full.

### Reuse the budget measurer and the pi `yaml` dependency
- Context: three adversary rounds found YAML forms the hand-rolled decoder missed.
- Choice:
  - offline numbers come from `scripts/workflow-context-budget --json`;
  - frontmatter goes through `yaml`, loaded with `createRequire(pi/package.json)` like `scripts/pi-skill-load-check`;
  - `name`, `description` and `when_to_use` must be strings;
  - invalid YAML is a hard violation.
- Rejected options: a second budget gate; comparing rounded `est_tokens` (a 1-char growth reads as +4 %).
- Rationale: rung 2/5 of 12b; one estimator.
- Consequences: `--skills` needs `bun install --cwd pi`, which the CI shell-docs job already runs.

### Park T4 rather than finish it first
- Context: root `PLAN.md` held T4 (READY, review run at D1) when the user opened T9.
- Choice: demote to park it, discard it via `plan-cleanup`, and keep its full body in `docs/plan/20260927-discarded-parked-t4-for-t9-audit.md`.
- Rationale: the user's new request; T4's diff stays untouched.
- Consequences: T4 needs its own resume; the token-bench baseline includes the T4 worktree state.

## Accepted Drift
- Original plan/spec: `token-bench` without any dependency; hand-decoded YAML.
- Implemented reality: `--skills` reuses the existing pi `yaml` package (AC4/AC7 reworded, stricter).
- Why accepted: reuse over reimplementation; recorded as a check-freeze demotion in the Decision Log.
- Original plan/spec: close in one run.
- Implemented reality: the first run ended `blocked` after F1 (D budget spent). A second, user-authorized review run went T1 → T2 → D1 → D2 → F1 and finished clean.
- Why accepted: bounded review machine (`workflow/skills/review-rounds.md`).

## Validation Evidence
- command: `scripts/verify-agentic-infra full|core|shell-docs|pi`, with RUN labels compared to the manifest selection
  - result: 81/81, 27/27, 75/75, 6/6; label sets equal, no duplicates
- command: `bun test pi/extensions/__tests__/`
  - result: 355 pass, 0 fail
- command: `bash tests/token-bench-smoke.sh` under Node 20.20.2 and 24.19.0
  - result: ok on both. Every folded fix has a smoke case that fails when the fix is reverted (checked by mutation)
- command: `scripts/token-bench --check`, `--skills --check`, `--live`
  - result: exit 0; live 18.4 k tokens in the repo, cost 0
- command: `scripts/research-proof-check` and `scripts/answer-quality-check --mode research` on the audit report
  - result: ok
- Reviews: fresh-context Logic and Spec hunters. Cross-family adversary Codex `gpt-6-astra`, effective model checked in every session: plan passes R1-R4; code passes T1-F1 in both runs. 22 findings accepted, 1 rejected. Final F1: Logic GO, Spec GO, Codex GO.

## Follow-up State
- Remaining risks:
  - `/context` is an internal Claude Code format; the parser fails closed.
  - GitHub Ubuntu CI was not run here.
  - Rewrite the baseline once T4 is committed or dropped.
- Parking lot:
  - T/D/F validator on the ledger;
  - skill fixes (`project-hunt`, `design`, contents headings, self-pointing adapter blocks);
  - per-route rule census;
  - escaped defects by tier;
  - name or retire `workflow-ship-metrics` and `workflow-ledger-census`;
  - decide on `t8b-runs/`.
- Superseded docs/specs: none.
- Next links: `docs/research/20260927-harness-practices-audit.md`, `docs/plan/20260927-discarded-parked-t4-for-t9-audit.md`.
