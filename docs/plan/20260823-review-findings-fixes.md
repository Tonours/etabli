# 2026-08-23 — Review findings fixes (7-round external review)

Distilled archive of the root PLAN.md implemented as `f35d672` (+ hunter/adversary folds). Source findings: `review-aggregate.md` + `round-1..7.md` at repo root.

## What shipped

1. **Gate honesty** — `verify-agentic-infra` accumulates FAILs (SUMMARY + exit 1), no more abort-on-first; `skill-lock` promoted to `core`; `skills-lock.json` regenerated (5 kernel skills, drift was intentional recentering work); `herdr` description fixture resynced (901→956 bytes); CI triggers on all branches.
2. **Oracle hardening (3 of 7 tasks)** — `review-isolation-sentinel`: parseable verdict + byte-identical runtime file + porcelain allowlist + no extra commits (`rev-list --count == 1`); `ready-implement`: exact expected-file SHA (`expected/src/fixture.sh`); `review-go-forbidden-empty-deciding`: BLOCK-only + deciding section must carry a `file:line` row. Smoke gained degenerate cases (GO WITH NOTES over empty deciding fails; mutated worktree fails).
3. **Dead code removal** — `route-context-manifest` artifacts deleted (4 files + gate row; ADR-0014 orphan); `cross_harness` lane deleted (TSV 6→5 cols, three scripts, smokes, AGENTS.md promise). Kept/restored: pi-sourced link cleanup on `.claude/.codex` as explicit policy (`prune_pi_sourced_skill_links` + fixer WARN) — the adversary caught that the old empty-lane prune was the only live cleanup.
4. **Docs museum** — 17 dated analyses → `docs/archive/` with status index; research doc paths fixed; ADR-0014 annotated (orphans now removed).

## Evidence

- `verify-agentic-infra full`: **69/69 PASS** (first green full since rounds measured it red+masking).
- Focused: harness-eval smoke, manifest smoke (now pins the accumulation construct), fix-links, deploy, pi tests (238+56), `verify:skills` — all green.
- simplify: clean (deletions + minimal constructs only).
- quality: shell+mjs+ts | mechanical fixed: 4 | findings: 0 open | status: clean.
- Logic hunter (fresh context, glm-5.3): GO WITH NOTES — 2 findings folded (dotted gpt-5.6 ids; settings-consistency.test.ts column model).
- Spec hunter (fresh context): GO WITH NOTES — major "oracles only partially hardened" rejected as plan-scoped (see Open), minors rejected with rationale (all_zero catalog rows and cursor-model enablement were pre-existing/user-requested, documented).
- Adversary code-diff (cross-model `cursor/grok-4.6` xhigh): GO WITH NOTES — 6 findings folded (commit-burial cheat, deciding-grep anchoring, pi-sourced prune restoration, research paths+ADR note, accumulation pin, remediation text), 2 rejected (scope drift = user request; row position = cosmetic).
- Event ledger: N/A — supervised session, not autonomous.

## Deliberately out (recorded for follow-up)

- GO-positive harness task + null-baseline in `harness_report` (aggregate action 2, remainder).
- Remaining oracle holes: `plan-draft-no-mutate` docs/plan allowlist, `review-spec-drift` GO WITH NOTES, self-declared sentinels (`no-parent-logic-claim`, `hunter-read-only`).
- Open architecture decisions: reconciler unification (C3), spec↔classifier ordinary-coding (C4), brain/obvault (C5), installer split/pins (C6), SPOF volume (C8), implementation-loop tiering (C9), 15 `all_zero` catalog rows.

## Lesson

The rounds' core diagnosis — "la décision est enregistrée, sa propagation ne l'est pas" — repeated itself intra-session: removing the "dead" cross_harness lane silently removed its only live behavior (surface cleanup). Dead-code removal needs a consumer/behavior inventory, not just a reference grep.
