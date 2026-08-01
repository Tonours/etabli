# Implemented: Honest token/context-efficiency benchmark + residual safe cuts

## Meta
- Date: 2026-08-01
- Source: root `PLAN.md` (Status READY) — harness efficiency honest benchmark
- Route: `plan-implement` (self-improvement of Etabli)
- Status: implemented + validated; archived. Root `PLAN.md` deleted post-archive.

## Goal
Make Pi & Claude harnesses as token- and context-efficient as is **honestly possible** without weakening invariants or reward-hacking. Deliver additive always-on/lazy-load metrics, apply residual safe cuts, prove held-out non-regression, and label the live gap without fabricating −50% tokens / ×2 throughput.

## Changes

### Additive metrics (`scripts/workflow-efficiency-report`)
- `always_on_context`: dev-repo (`~/.claude/CLAUDE.md` + project `CLAUDE.md` + `AGENTS.md`) and deployed (`claude/CLAUDE.md`, `pi/AGENTS.md`) with uncached + cached-amortized (0.1×) token estimates via `ceil(chars/4)`.
- `lazy_load`: all `workflow/**/*.md` on-demand corpus + `lazy_load_ratio` = lazy / (lazy + always_on_dev).
- Pinned 6-file `instruction_budget` set and targets **unchanged**.

### Smoke (`tests/workflow-efficiency-report-smoke.sh`)
- Strengthen-only assertions for new fields; all prior budget/stretch/file-set pins retained.

### Safe residual cuts
| Cut | Result |
| --- | --- |
| Remove Claude trailer (“Follow this route…”, “native surfaces…”) | **applied** |
| Remove Claude `Capabilities: workflow/runtime-capabilities.json` line | **rejected** — pinned by `tests/claude-hooks-smoke.sh` |
| Compress Claude multi-execution panel guidance | **applied** |
| Compress Pi multi-execution scout/council + drop Pi trailer | **applied** |
| Further always-on ADR index / obvault / Ambient / `/goal` pins | **no further safe cut** (documented) |

Router source size (HEAD → worktree):
- `pi/extensions/lib/workflow-router-runtime.ts`: 8215 → 7457 chars (−758 ≈ −190 tokens est.)
- `claude/hooks/workflow-router-lib.mjs`: 41136 → 40500 chars (−636 ≈ −159 tokens est.)

Tests updated to assert compressed multi-execution semantics (not the old long phrases).

## Before / after (offline)

| Metric | Before | After | Notes |
| --- | ---: | ---: | --- |
| instruction_budget current_tokens | 1556 | 1556 | 6-file set unchanged; within stretch 1891 |
| instruction_budget file set | 6 pinned | 6 pinned | unchanged |
| instruction_dup_sections | 0 | 0 | |
| source_of_truth_conflicts | 0 | 0 | |
| always_on_context dev uncached | n/a | **1674** | new metric |
| always_on_context dev cached_amortized | n/a | **167** | 0.1× proxy, not live |
| always_on deployed claude / pi | n/a | **331 / 385** | new |
| lazy_load total_tokens | n/a | **37657** | workflow/**/*.md |
| lazy_load_ratio | n/a | **0.957** | majority on-demand (decay) |

## Live axis (labelled, not invented)

Source: `docs/harness-optimization-bench/live-ab-tokens-throughput.json` (fresh opt-in run 2026-08-01 via `RUN_REAL_MULTI_MODEL=1`).

| Metric | Panel vs baseline | Promotion target | Met? |
| --- | ---: | --- | --- |
| TokensParSuccès ratio | 1.109× | ≤0.50× | **false** |
| DébitVérifié ratio | 0.301× | ≥2.00× | **false** |
| Verdict | measured-fail-targets | | floors OK; panel worse than baseline |

Do **not** claim −50% tokens or ×2 verified throughput from this run.

## Validation

| Command | Result |
| --- | --- |
| `bash tests/workflow-efficiency-report-smoke.sh` | EXIT 0 |
| `bash tests/claude-hooks-smoke.sh` | EXIT 0 |
| `bash tests/dual-runtime-guard-matrix-smoke.sh` | EXIT 0 |
| `scripts/verify-agentic-infra core` | EXIT 0 |
| `bun test pi/extensions/__tests__/` | EXIT 0 (225 pass) |

## Adversary / review (recorded)

### Plan adversary
- **GO** with notes: literal “100% more efficient” rejected as reward-hack (Decision Log in READY plan); success redefined as honest max reduction + metrics + labelled live gap.
- Accepted: additive always_on metric closes undercount of real always-on chain vs 6-file budget.
- Rejected: cutting capabilities line; weakening smoke pins; inventing live token wins offline.

### Code-diff review
- **GO**: metrics additive only; cuts preserve `/goal` line, capabilities pin, multi-execution invariants (parent-only writer, ≤6 claims, soft caps, wall-clock not stop).
- Note: multi-execution compression updates tests to new phrasing while keeping semantic asserts.

### Fresh-context review
- Implemented by same author in this session; residual risk is wording drift on council policy (mitigated by retained key phrases + green dual-runtime / extension tests). Not a fully independent subagent — label **proxy_supported**.

## Event ledger
`.workflow/etabli-harness-efficiency-honest-benchmark/events.jsonl`

## Decision Log
- 2026-07-31 (plan): Literal ≥100% efficiency not honestly achievable; redefine success.
- 2026-08-01 (implement): Ship always_on/lazy_load meters; apply residual router cuts only when smokes stay green; stop at frontier of pinned invariants.
