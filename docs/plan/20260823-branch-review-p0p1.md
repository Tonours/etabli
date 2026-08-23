# 2026-08-23 — Branch-review P0/P1: state integrity, accounting, guards

Distilled archive of the root plan removed via `plan-cleanup --discard implemented-archived-p0p1` (terminal handoff; this file is the substantive record). Implemented as `7484b59` + `9e9aea3`. Source: `branch-review-aggregate.md` (C1-C11).

## What shipped

1. **Oracle state integrity** — `harness_prepare_worktree` records HEAD outside the worktree; every oracle requires HEAD identity (kills commit and `--amend` burial); the four naked oracles gained porcelain allowlists + SHA of the file under review; porcelain enumerates renames on both sides; the live-run pin is driver-held (`BASELINE_EXPECTED` env, unreachable to the subject) with the file fallback kept for offline grading.
2. **Both floors published** — `constant-baseline` subcommand (fabricated BLOCK transcript) beside `null-baseline`: null 1/8, constant **6/8** measured and documented; smoke asserts the floors (null exactly 1 = plan-draft; constant ≤ 6, GO-control and implement must fail).
3. **Honest accounting** — `SUMMARY: %d/%d checks passed/failed` printed by the runner; the two earlier archives corrected 80/80 → 69/69 (the previous count had aggregated nested PASS lines — the exact accounting-class bug the branch set out to fix).
4. **Sentinel/contract alignment** — `review-isolation-sentinel` accepts the complete sentinel signature without a verdict (review.md hard-stop is the truth again); a verdict after sentinel is tolerated unless GO.
5. **Fail-closed guards** — installer refuses to prune on empty pi_core/agents_visible keep-lists; fixer aborts loudly on a degenerate catalog (absent catalog keeps degraded mode); `prefer-cursor-agent.sh` returns 1 on write failures and only removes grok-colliding symlinks (target equality), same in the rc hook.
6. **Gate/CI** — `shell_syntax` recursive over scripts/tests (returns non-zero on any syntax error, stderr preserved); CI `concurrency: cancel-in-progress`; grok removed from hunter-read-only runners (manifest/doc coherence); dead `/skill:caveman` `/skill:grill-me` announcements removed; final-line verdict extraction; stale-cell refusal hoisted to run; `run` exits non-zero on red cells.

## Evidence

- `tests/etabli-harness-eval-smoke.sh`: ok — degenerate cases: mutated worktree, amend burial, committed extra, forged baseline file vs BASELINE_EXPECTED precedence, contradictory isolation lines, GWN gates, both baselines.
- `verify-agentic-infra full`: **SUMMARY: 69/69 checks passed**. fix-links, install, deploy, manifest smokes green.
- Logic hunter (fresh ctx): BLOCK on first pass (shell_syntax swallow, red_cells unset, pin reachable, stale-cell asymmetry, one-array sentinel) — all folded. Spec hunter: majors folded (same + dead announcements), minors rejected with rationale (review corpus at root = user deliverable; grok deny-write mitigated by state checks and documented).
- Adversary cross-model (cursor/grok-4.6): BLOCK on second pass (mkdir/check order inversion killing live runs, BASELINE_EXPECTED not in oracle prefix, fixer both-arrays, direction files in patch) — all folded, re-validated 69/69.
- Postmortem: the direction council's hygiene loop reverted working-tree folds once (baseline taken before the edits) — recovered from the pinned patch; lesson: never run an artifact-writing background council and an implementation loop in the same tree without committing between phases.

## Known limits (open)

- Constant floor 6/8: six cells still accept fabricated transcripts; next step is out-of-band artifact grading (cell-imposed file hashed by the oracle) — the load-bearing cells today are ready-implement (state SHA) and review-go-clean-diff (GO-only).
- Architecture decisions routed to the direction council (see `direction-aggregate.md`): reconciler table, spec↔classifier (ordinary coding → direct edit), brain/obvault resolver, installer split, ritual tiering (consensus: risk-proportional),  live (kill dominance protocol, keep structural pin).
