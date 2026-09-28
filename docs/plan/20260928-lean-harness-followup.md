# Implemented: lean harness follow-up — run evidence kept, merged worktree removed, deploy outcome recorded

## Metadata
- Archived: 2026-09-28
- Source plan: `PLAN.md` — lean harness follow-up — keep the run evidence, remove the merged worktree, record the deploy outcome
- Source plan SHA-256: `80d688a1c29c4b36c25aa23eecd3aa76feb45ba83c8d78068fc284188b28d9d5`
- Status: IMPLEMENTED
- Commit / branch: `docs/lean-harness-followup` on `main` at `c6701a0`; not pushed
- Workflow initiative: `lean-harness-followup` (follows `lean-harness`, whose ledger stays `blocked`)

## Outcome
- The deploy that `docs/plan/20260928-lean-harness.md` left pending ran after the user authorized it:
  - `main` moved by fast-forward from `5c6d3fb` to `c6701a0`;
  - `scripts/deploy-agent-workflow --apply` linked `claude/hooks/session-state.mjs` and set `autoMemoryEnabled: false` in both Claude homes (`~/.claude` and `CLAUDE_CONFIG_DIR`); at deploy time, that key was the only change in each `settings.json` (diff against the `settings.json.bak.20260928-092848` backups; later session setting changes are not part of this deploy);
  - `scripts/claude-hooks-merge`, run once per home, added only the SessionStart `compact|resume` entry;
  - `scripts/claude-hooks-check` reports `ok, all fragment hooks wired` for both homes.
- On `c6701a0` after the deploy, `scripts/verify-agentic-infra core` gives `SUMMARY: 26/26 checks passed` and bun gives 354 pass / 0 fail.
- The lean-harness run dir (ledger, experiment drivers, sealed snapshots, receipts; 19 files) now lives in the main checkout at `.workflow/lean-harness/`, with SHA-256 manifests identical to the worktree copy. The ledger validates there with `--profile blocked-terminal` (166 events).
- The worktree `/Volumes/Crucial/work/etabli-lean-harness` and the merged branch `refactor/lean-harness` are removed. No other worktree or branch was touched.

## Context
- `docs/plan/20260928-lean-harness.md` still says "not pushed, merged or deployed" and core 25/26. It is immutable (`workflow/plan-archive.md`), so this record carries the later outcome.
- `scripts/workflow-event` refuses events after a terminal (`scripts/workflow-event:198`), so the lean-harness ledger stays `blocked` and its `needed_input` is answered here.

## Decisions
### Keep the fail-closed guard denials
- Context: the read-only guard now denies harmless idioms such as `rg $HOME`, `git diff *`, `find *` and `diff a*`.
- Choice: no change.
- Rejected options: re-allowing them now. Each review round found a new bypass through expansions and globs, and no read-only agent needs these forms today.
- Consequences: when a real need shows up, add one targeted exception with a failing fixture first and a bypass fixture beside it.

### Park the open experiment questions
- Context: P5 rests on 2 pointer-era sessions, the P6 capsule was never tested on quality, and P7 had 4 eligible held-out runs for a floor of 15, with no priced pass.
- Choice: no new experiment now; each needs data that does not exist yet.
- Consequences: rerun P7 once 15 or more held-out runs have an eligible decision point and a priced plan pass (provenance plus a cited list price); new appends now require `model_provenance`, which covers only the first half of the pricing condition.

## Accepted Drift
- Original plan/spec: none.
- Implemented reality: as planned.
- Why accepted: not applicable.

## Validation Evidence
- command: SHA-256 manifest diff of the run dir, worktree against main
  - result: empty, 19 files
- command: `scripts/workflow-event validate lean-harness --profile blocked-terminal`
  - result: `166 events, ok`
- command: `git worktree list`, `git branch --list refactor/lean-harness`
  - result: no lean-harness worktree, no branch
- command: `scripts/verify-agentic-infra core`
  - result: `SUMMARY: 26/26 checks passed`
- command: `bun test pi/extensions/__tests__/`
  - result: 354 pass / 0 fail

## Follow-up State
- Remaining risks: none new.
- Parking lot: a guard exception on real need; P5, P6 and P7 reruns on new data.
- Superseded docs/specs: the "not merged or deployed" and core 25/26 lines of `docs/plan/20260928-lean-harness.md`.
- Next links: `docs/plan/20260928-lean-harness.md`, `docs/research/20260928-lean-harness-experiments.md`.
