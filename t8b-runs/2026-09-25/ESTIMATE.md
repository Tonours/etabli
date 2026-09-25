# T8b cost estimates (probe-grounded)

Cap: $100 hard, shared by probes + screening + economic. Prices (frozen):
in $1.40, out $4.40, cached-in $0.26, cache-write $0.00 per MTok
(source: https://docs.z.ai/guides/overview/pricing, fetched 2026-09-25).

## Observed probe profiles (freeze v2–v4 invocation, unchanged since)

| Probe | Usage in/out/cr/cc | Cost |
|---|---|---|
| A tiny | 415/3/0/0 | $0.0006 |
| B hunter-clean (real template) | 1532/444/192/0 | $0.0041 |
| C emit e2e (2 reads + emit) | 1570/222/4416/0 | $0.0043 |
| D dispatch e2e (parent + 2 children) | 6206/4371/15040/0 | $0.0318 |

Probes total: $0.0409.

## Screening FULL (72 runs) — pre-launch estimate

- plan-loop (36 runs): in 15k / out 4k / cr 5k ⇒ $0.040/run ⇒ $1.44
- hunter (30 runs): $0.006/run (probe B + margin) ⇒ $0.18
- s10 pointer (6 runs): $0.045/run (probe D + margin) ⇒ $0.27
- FULL expected ≈ $1.89; worst case 72 × $1.00 = $72 ≤ $99.96 remainder ⇒ LAUNCH (v5).

## v5 discard + v6 revision

v5 screening stopped after 13 runs ($1.18, cumulative $1.22) for the
section-tree grader bugfix; those runs are DISCARDED (instrument never
completed) and preserved under `screening-v5-discarded/`. Observed v5
plan-loop mean ≈ $0.10/run (13 KB reasoning-heavy outputs).

- Screening FULL (v6) revised: 36×$0.11 + 30×$0.006 + 6×$0.045 ≈ $4.40.
- Worst case 72 × $1.00 = $72 ≤ $98.78 remainder ⇒ LAUNCH (v6).

## Economic FULL (36 runs) — gated on screening completion

Pre-estimate: 36 × $0.006 ≈ $0.22 (recomputed from observed screening
hunter profiles before launch; launches iff it fits the remainder then).

## v6 discard + v7 revision

v6 screening stopped during s3 (13 runs, cumulative $1.22) for two
instrument fixes: plan-loop contract staging (R-T8b-11 — unstaged
candidates read only the subject file, INVALID-by-construction) and
verdict-claim line detection (R-T8b-6 complement — bare **READY**
claims escaped the colon-only detector). v6 runs DISCARDED (instrument
never completed), preserved under screening-v6-discarded/. v7 FULL
revised: 36x$0.12 + 30x$0.006 + 6x$0.05 ~= $4.80; launches iff
FULL fits the remainder then.

## v7 discard + v8 revision

v7 screening stopped during s3 (14 runs, cumulative $4.26) for two
instrument completions: arrow-citation detector (v7 canonical lists
use -> exclusively) and explicit SKILL path in the candidate contract
(bare reference unresolved, 4/5 systematics observed). v7 runs
DISCARDED (instrument never completed), preserved under
screening-v7-discarded/. v8 FULL ~= $5.00; launches (remainder $95.74).
