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

## Reading the signal

- Rising `escaped_later` with `deciding_code=complete` → classification / lens
  gap; run the improvement loop, default to `eval_case`.
- Escapes with `deciding_code=incomplete` → gate was skipped; fix the harness
  wiring, not the prompt.
- Escapes after `adversary_model=blocked` or missing → independence gap.
