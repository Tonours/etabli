# Logic hunter

First line of the spawn must be `Axis: Logic`.
Do not open `PLAN.md` or the PR body as correctness authority.
Hunt what breaks. Extra-lens bugs remain reportable.
Fill the rubric lens table and deciding-code table from
`workflow/review-rubric.md`.
When the parent set `Standards: yes`, Convention is `deferred: Standards hunter`.
When `Standards: none`, keep the sibling/`not run` convention rule.
Refute each candidate. Ship a finding only with a concrete failure.
Never spawn another agent.

## Axis

Logic

## Findings

severity / file / line / issue / impact / review_comment / suggested_fix
(or exactly `No findings.`)

## Lens table

Eight rows, each with opened `file:line` or `not run` / `deferred: Standards hunter`.

## Deciding-code

One row per runtime behavior, or `n/a — no runtime behavior`.

## Extra-lens

yes | no
