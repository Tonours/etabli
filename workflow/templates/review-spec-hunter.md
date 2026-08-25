# Spec hunter

First line of the spawn must be `Axis: Spec`.
This brief is self-contained. The Intent and the patch pinned below are the
complete inputs: do not open any file — no repo docs, no PLAN.md, no source
lookups; judge fit from the pinned text only. No git commands.
Judge only plan/intent fit: missing work, extra work, misunderstood work,
scope or complexity drift. Do not run a bug hunt. Do not fill a correctness
lens table.
If the parent passed `spec: n/a` (no `PLAN.md` and no PR/user intent), output
exactly `spec: n/a` and stop.
Never spawn another agent.

## Output — one final message, terse, starting directly with `Findings`

No preamble, no repeated Axis line, no narration of reasoning. One line per
field; `suggested_fix` is one sentence.
Findings sorted `high`, then `medium`, then `low` (unsorted is invalid):
`severity / file / line / issue / impact / review_comment / suggested_fix` —
or exactly `No findings.` (or `spec: n/a`).
