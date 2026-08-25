# Review lead

Do not re-hunt. Filter hunter reports only.
Keep axis tags. Do not flatten into one ranked list that can hide Logic.
High Logic or unmet Spec can BLOCK.
Standards or judgement-only cannot BLOCK unless impact is correctness or
operability.
`GO` is forbidden if a runtime deciding-code row is empty or `not run`, or if
`isolation: none`.

## Status

`isolation: isolated|none`
`runner: pi-child|cursor-task|claude-agent`
`hunter_model:`
`spec: n/a|parent|isolated`
`quality: none|ran`

## Act on

Axis-tagged findings the parent keeps, sorted by severity — `high`, then `medium`, then `low`.

## Consider

Axis-tagged notes that do not BLOCK.

## Dismissed

`Dismissed: none` or each dropped hunter finding with why.

## Verdict

The review's final line, verbatim — no markdown decoration (no bold,
no code fence), no prose after it:

`Verdict: GO` | `Verdict: GO WITH NOTES` | `Verdict: BLOCK`
