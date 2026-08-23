# 2026-08-23 — Ratified decisions: spawn-evidence, C4, C9, , obvault, dead sweep

Distilled archive of the root plan (terminal handoff via `plan-cleanup --discard implemented-archived-ratified`). Tier: high-risk (kernel classifier + gate + oracles touched). Source: `direction-aggregate.md` + user arbitration 2026-08-23.

## What shipped

1. **Spawn-evidence (state-derived isolation)** — PATH wrapper logs every real `pi` invocation to a driver-owned file (path baked into the wrapper, `exec`-transparent) on non-hide_spawn review tasks; `harness_require_spawn_evidence` makes `isolation: isolated` claims state-derived. Constant fabrication floor **6/8 → 3/8** (remaining passes are honest-outcome coincidences: sentinel hard-stop, spec-drift BLOCK, plan-draft abstention). Wrapper execution is smoke-pinned (transparency + logging). Residual documented: a fabricator discovering the wrapper could forge the log — the two state-bound tasks remain load-bearing.
2. **C4 ordinary coding → direct edit** — implement requests with no planning lock (missing **or unknown** — the Pi adapter maps absent plans to unknown) route to `answer`/direct-edit. plan-implement reserved for: explicit plan asks, large/multi-slice signals (`LARGE_CHANGE_PATTERN` incl. roadmap multi-item), autonomous plan-loops, PREPARE_FOR_REVIEW, active plan cycles (draft/challenged resume the plan). Explicit planning asks (`PLAN_REQUEST_PATTERN`) outrank everything. Router: accuracy=1, alignment=1, fixtures + sync + agent-scenarios + Pi tests aligned (238/238).
3. **C9 risk-tiered ritual** — `small` (runs outside the plan gate: recon, edit, checks, 12b/12c, self-review), `standard` (full loop; same-family double-sample acceptable at 13b), `high-risk` (cross-model adversary mandatory). spec.md routing note + adversary.md tiered hard gate; quick-card/ship references left as review-contract ( hunters path), completion evidence qualified per tier.
4. ** live requalified abandoned** — README, how-it-works, live-gate/live-blocked/live-status jsons (`abandoned ... structural pin retained`, reopen only on new event).  smoke accepts the status while keeping honesty invariants. Structural pin (23/23) kept.
5. **Obvault scope-aware resolver** — `OBVAULT_ROOT` exclusive; work scope → `~/work/brain` if present else `~/work/obvault` (documented live reality: brain absent); personal → `~/work/obvault`. Emitted retrieval command built from the resolved root (no more cross-scope command). AGENTS.md/CLAUDE.md/pi-AGENTS.md/claude-CLAUDE.md/quick-card/obvault-memory all point to the resolver.
6. **Dead sweep** — scaffold: program cluster + evidence-proof + program schema/templates removed from FILES (**−93 Ko/project**, 341→248 Ko measured); frozen program control plane annotated `FROZEN` (kept in-repo:  pin references owner_paths, session-handoff consumes it); etabli-repo-only annotations on spec/dogfood/investigation/orchestration refs; dead porcelain allowlist entries dropped (6 oracles); TSV opt-in shelf comment; chrome-devtools-mcp pinned @1.7.0; capabilities refreshed (guard re-proofs dated 2026-08-23) + honest grok/codex rows (skills-only, blocked/unknown).

## Evidence

- `verify-agentic-infra full`: **SUMMARY: 69/69 checks passed** (final).
- Focused: harness smoke (degenerate spawn/amend/baseline-forgery cases + wrapper execution), router-eval 1/1, Pi tests 238/238, scaffold/contract-coverage/docs/obvault/caps/guard-matrix smokes green.
- simplify: clean (additions minimal, one dead disjunct removed). quality: clean | mechanical fixed: 3 (object-guards jq, smoke skips, naming).
- Logic hunter: GO WITH NOTES — 5 findings folded (adapter missing→unknown bypass, dead PLAN disjunct, obvault command root, small-tier completion evidence, go-forbidden spawn wiring).
- Spec hunter: 1 high (half-done sweep) folded via freeze + scaffold retraction + annotations; fixture boundary ratified in Decision Log.
- Adversary cross-model (grok-4.6 xhigh): BLOCK — small-tier self-contradiction, PLAN_PATTERN precedence steal, scaffold dangling refs, untested wrapper; all folded and re-validated.

## Known limits (open)

- Fabrication ceiling: forging the spawn log after discovering the wrapper remains possible; load-bearing cells are ready-implement + go-clean-diff (state/spawn-bound).
- Pi adapter still maps "brouillon/draft" prompt words to `draft` (an ordinary fix mentioning "draft" resumes plan-implement) — minor, documented.
- C3 reconciler + C6 installer split: deferred to next touch of those files (user decision).
