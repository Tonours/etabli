# Review effectiveness metrics

Append-only log. One row per reviewed PR (or per ship handoff). Purpose: measure
whether escaped defects drop after the deciding-code / cross-model gates — not
dashboard theatre.

Contract: `workflow/skills/reviewer-improvement-loop.md`.
Escaped records: `workflow/templates/escaped-defect.md`.

## How to append

When a ship or autonomous plan-implement completes, or when a post-GO defect is
recorded, append one row. Do not rewrite history.

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

## Log

| date | pr | verdict | deciding_code | reviewer_model | adversary_model | escaped_later | buckets |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Reading the signal

- Rising `escaped_later` with `deciding_code=complete` → classification / lens
  gap; run the improvement loop, default to `eval_case`.
- Escapes with `deciding_code=incomplete` → gate was skipped; fix the harness
  wiring, not the prompt.
- Escapes after `adversary_model=blocked` or missing → independence gap.
