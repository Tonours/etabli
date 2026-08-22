# Implemented: Etabli harness live-eval suite

## Metadata
- Archived: 2026-08-22
- Source plan: `PLAN.md` — Etabli harness live-eval suite (DeepSWE-style, Pi glm-5.3 max + Grok 4.6 xhigh)
- Source plan SHA-256: `a84954542c9d805965c593e0cd884956ca3cd0671126336c4e94938560069761`
- Status: IMPLEMENTED
- Commit / branch: uncommitted on `refactor/skill-default-load`

## Outcome
- Frozen v1 harness eval under `tests/fixtures/harness-v1/` (7 original tasks, executable oracles, skill-eval-shaped manifest).
- Driver `scripts/etabli-harness-eval` (`print-argv`, `grade`, `run`, `report`) with pinned Pi/Grok argv, last-line verdict parser, fail-closed nonzero runner exit, and kept cell directories.
- Hermetic smoke in `full`/`shell-docs`; live canary skip-exit-0 unless `ETABLI_HARNESS_EVAL=1`.
- Review-hunter tasks are Pi-only; Grok cells are plan/implement/read-only.

## Context
- DeepSWE method transfer: original tasks, behavior verifiers, fixed runners. Not DeepSWE's SWE tasks.
- `workflow/` is the live symlink surface; fixtures stay under `tests/fixtures/` so oracles are not injected into every project.
- Root `PLAN.md` is gitignored; fixture `PLAN.md` files are re-included.

## Decisions
### Pi-only review hunters
- Context: `workflow/skills/review.md` has no Grok hunter adapter.
- Choice: `review-*` and `no-parent-logic-claim` run on Pi only.
- Rejected options: add a Grok review adapter in this slice; score impossible Grok review cells.
- Rationale: a Grok column on hunter tasks would measure missing contract, not harness behavior.
- Consequences: Grok matrix is `plan-draft-no-mutate`, `hunter-read-only`, `ready-implement-touches-only-plan-files`.

### Spawn stubs instead of PATH wipe
- Context: launching wrapper `pi` with `PATH=/usr/bin:/bin` either restores homebrew or cannot find `node`.
- Choice: node-shebang `pi` plus prepended stub `bin/` that prints `HUNTER_SPAWN_UNAVAILABLE`.
- Rejected options: PATH subtraction of the parent; skipping the isolation cell entirely.
- Rationale: children calling `pi`/`claude`/`agent` hit the stub; the parent still starts.
- Consequences: live isolation canary needs `node` and a node-shebang `pi`.

## Accepted Drift
- Original plan/spec: fixtures under `workflow/eval/harness-v1/`; eight tasks including `cursor-not-required`; Grok on the full matrix; live mktemp transcripts.
- Implemented reality: `tests/fixtures/harness-v1/`; seven tasks plus a driver cursor-absence assertion; Grok subset; cells kept under a printed dir / `ETABLI_HARNESS_EVAL_DIR`.
- Why accepted: folded plan-mode Opus adversary (H1–H5, M1) and Logic/Spec plus Fable code-diff notes (spawn stubs, allowlists, fail-closed, keep transcripts, unknown `--task`).

## Validation Evidence
- command: `bash tests/etabli-harness-eval-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/agentic-infra-manifest-smoke.sh`
  - result: pass (2026-08-22)
- command: `bash tests/workflow-docs-smoke.sh`
  - result: pass (2026-08-22)
- command: `env -u ETABLI_HARNESS_EVAL bash tests/etabli-harness-eval-live.sh`
  - result: skip exit 0 (2026-08-22)
- review: Logic+Spec `claude-opus-5-thinking-high`; isolation `cursor-task`; folded high/medium (spawn stubs, `.workflow/` allowlist+gitignore, `run` status capture, fail-closed exit, print-argv reuse, Act-on FORBIDDEN.txt). Remaining notes: smoke still uses a synthetic preparer (CI bound).
- code-diff adversary: `claude-fable-5-thinking-high` GO WITH NOTES; folded H1 keep cells, M1 unknown task, M2 Act-on mention, M3 run duration. Cross-family vs implementer grok-4.6.
- simplify: removed 6
- quality: ran (sibling compare vs `tests/skill-eval-smoke.sh` and `scripts/pi-review-hunter`)

## Follow-up State
- Remaining risks: live billed runs are still a human checkpoint; hide-spawn PATH may hide `rg`; Grok mismatch grep is best-effort beside fail-closed exit.
- Parking lot: `valid` JSONL field; smoke calling `deploy-workflow`; pass^k as a v1 gate.
- Next links: `ETABLI_HARNESS_EVAL=1 scripts/etabli-harness-eval run --runner pi --task review-isolation-sentinel`
