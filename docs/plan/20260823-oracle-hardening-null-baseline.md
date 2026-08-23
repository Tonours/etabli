# 2026-08-23 — Oracle hardening + GO-positive control + null baseline

Distilled archive of the root PLAN.md "Fermer les trous d'oracles restants (C1) + contrôle positif GO + null baseline". Follows docs/plan/20260823-review-findings-fixes.md (action 2 remainder).

## What shipped

1. **Four oracles hardened** — `plan-draft-no-mutate`: porcelain allowlist drops `docs/plan/` (DRAFT writes there fail); `review-spec-drift`: BLOCK-only (documented spec violation is never GO WITH NOTES); `no-parent-logic-claim`: exhaustive isolation signature (isolated pair OR complete sentinel tuple) with the `isolation: none` + GO ban applied unconditionally before any short-circuit; `hunter-read-only`: full review protocol (tables, parseable verdict, deciding `file:line`, isolation line) — inaction fails.
2. **`review-go-clean-diff` (8th task, held_in, pi)** — positive control where only `Verdict: GO` passes; contradictory isolation lines rejected; overlay PLAN.md tracked; fail fixture byte-identical to pass except the verdict.
3. **`null-baseline` subcommand** — offline, grades every task against an empty transcript (`runner: "null"`); smoke bounds the floor (`null_pass ≤ 2`); porcelain enumeration switched to `-uall` (untracked dirs no longer collapse).
4. **Docs** — measured floor published: **null pass@1 = 1/8** (only plan-draft passes; abstention is correct there). Before hardening a constant do-nothing transcript passed 5-7/7.

## Evidence

- `tests/etabli-harness-eval-smoke.sh`: ok — includes degenerate cases for all four hardened oracles + contradictory-transcript pins + GO/GWN pair + null-baseline structural asserts.
- `verify-agentic-infra full`: 69/69 PASS (denominator printed by the runner).
- simplify: clean (rewrites only). quality: bash-harness | findings folded.
- Logic hunter (fresh ctx): GO. Spec hunter (fresh ctx): 4 findings folded (−uall declared in Decision Log; overlay PLAN.md added; fail fixture verdict-only delta; formatter split committed separately as b088791).
- Adversary cross-model (cursor/grok-4.6 xhigh): GO WITH NOTES — none+GO regression + GO-task isolation exclusivity + comment/comment-mode nits, all folded and pinned by new smoke cases.

## Known limits (open)

- Transcript grading remains textual: a policy fabricating exact expected strings could still pass some tasks (null baseline measures the floor, not that ceiling — documented in docs/harness-eval.md).
- Kernel guard ergonomics (composed read-only commands blocked under READY/CHALLENGED) — separate kernel work.
- Architecture decisions C3-C9 remain open (reconciler, spec↔classifier, brain/obvault, installer split, SPOF volume, ritual tiering, all_zero rows).
