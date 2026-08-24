# Review effectiveness metrics

One row per reviewed PR (or per ship handoff). Purpose: measure whether escaped
defects drop after the deciding-code / cross-model gates — not dashboard theatre.

Contract: `workflow/skills/reviewer-improvement-loop.md`.
Escaped records: `workflow/templates/escaped-defect.md`.

## Storage (same rule as escaped-defect)

| Stack | Where the log lives |
| --- | --- |
| Etabli harness PR | `workflow/self-improvement/review-metrics.md` in this repo |
| Personal stack | obvault (bounded shadow per `workflow/skills/obvault-memory.md`) |
| Work stack | brain |

Never write employer / work-stack rows into the etabli repo log. Reusable
eval cases still land in `workflow/self-improvement/reviewer-eval-corpus.md`.

## How to write

**One row per PR.** Do not rewrite history of other rows.

- A review that ends `Verdict: GO` or `GO WITH NOTES` appends its row **at the
  GO**, before the ship handoff is done (`escaped_later` starts at 0). A GO
  with no row is an incomplete review output: the denominator of
  `escaped_per_go` is the GO count, and an unlogged GO silently shrinks it.
- Ship / autonomous plan-implement completes → **append** a row if none exists
  yet for that PR (`escaped_later` starts at 0).
- Post-GO escaped defect recorded → **update** that PR's `escaped_later` and
  `buckets` columns. Create the row only if it was missing.

| Column | Meaning |
| --- | --- |
| date | YYYY-MM-DD |
| pr | owner/repo#n or local branch |
| verdict | GO / GO WITH NOTES / BLOCK |
| deciding_code | complete / incomplete / n/a |
| reviewer_model | model id or `fresh-subagent` |
| adversary_model | model id or `same-family-pass: double-sample` or `blocked` |
| escaped_later | 0 / n (filled when Macroscope, colleague, CI, or prod finds a miss) |
| buckets | comma-separated buckets from escaped-defect records, or `-` |

## Log (etabli harness only)

| date | pr | verdict | deciding_code | reviewer_model | adversary_model | escaped_later | buckets |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-08-24 | etabli@b7a0112 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@c8e939d | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@bc2465a | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@600b361 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@5d5e3a7 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@51bb7f8 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@427666e | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@0fc33bc | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@1c1897a | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@03fe4d1 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@6a59829 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@cc041e3 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@84b1ad5 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@21eb509 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@1a9ec62 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@910b7b4 | GO | n/a | unrecorded | unrecorded | 0 | - |
| 2026-08-24 | etabli@31f6d95 | GO | n/a | unrecorded | unrecorded | 0 | - |

### Backfill provenance (2026-08-24, CR-A3)

The rows above were backfilled from merge history: seventeen etabli ship
handoffs that passed the full gate stack (`bun test pi/extensions/__tests__/` +
`scripts/verify-agentic-infra core`) and for which no escaped-defect record
exists anywhere (`escaped_later = 0`). Pre-2026-08-24 ship handoffs did not
record the reviewer output, so `deciding_code` is `n/a` and the model columns
are `unrecorded` — the fields are left unknown rather than invented. The
work-stack events of the same period (agent-nodejs #1809/#1810/#1811,
employer #9917, f-f-z #45) stay out of this log per the storage rule; their
reusable cases live in `workflow/self-improvement/reviewer-eval-corpus.md`.

## Reading the signal

The loop's target metric is **`escaped_per_go` = Σ `escaped_later` / count(GO ∪
GO WITH NOTES rows)** — real PRs, not findings count. A log with zero rows is
an unmeasured loop, not a clean one.

- Rising `escaped_later` with `deciding_code=complete` → classification / lens
  gap; run the improvement loop, default to `eval_case`.
- Escapes with `deciding_code=incomplete` → gate was skipped; fix the harness
  wiring, not the prompt.
- Escapes after `adversary_model=blocked` or missing → independence gap.
