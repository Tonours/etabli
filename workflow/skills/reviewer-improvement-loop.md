# Reviewer Improvement Loop Contract

How the `reviewer` agent gets better at catching defects, driven by the defects it
actually let through.

The target is a real number: **escaped defects per reviewed PR**, where an escaped
defect is one that `reviewer` passed and a later gate caught (Macroscope, a human
reviewer, CI, production). Not "review quality" in the abstract.

## Why this is not "add the miss to a checklist"

The obvious loop is: a bug escapes, append a rule about it to the reviewer prompt.
That fails, and the failure is measured, not theoretical:

- Long instruction lists degrade attention to their own middle. Accuracy on
  material placed mid-context drops by over 30%. Every rule appended dilutes every
  other rule.
- Handing a reviewer more directives measurably *raises* false positives: it starts
  reporting against the checklist rather than against the code.
- Precision is already the binding constraint. Untuned LLM reviewers run under 10%
  precision on real PRs. Growth in instructions pushes the wrong direction.

So the loop keeps the prompt roughly constant in size. Individual misses go into an
evaluation corpus and, where they generalize, into a **bounded** taxonomy of lenses.
They do not accumulate as prose.

## The output contract is the lever, not the instruction

Measured on this loop's first run: seven lenses were added to the agent definition
and to the rubric, and the agent ran none of them — it reported against the rubric's
existing section headings instead. Adding a mandatory output table, one row per lens
naming the `file:line` opened, flipped three of four known misses to caught. Nothing
else changed.

The rule this gives: **a verification step the agent can skip without the skip being
visible is a step that does not exist.** When a miss lands in
`lens_existed_not_run`, the fix is almost never to reword the instruction. It is to
make the omission show up in the output.

Prefer, in this order:

1. constrain what must be **reported** (a required row, a required citation)
2. constrain what must be **retrieved** (name the file to open)
3. only then, add or reword an instruction

## Inputs

Evidence that can be inspected again:

- Macroscope findings on a PR the `reviewer` agent already passed. The highest
  quality signal available: an independent reviewer, on the same diff, at the same
  commit.
- human review comments that name a defect, not a preference
- CI failures on a branch the reviewer passed
- production incidents traceable to a reviewed change
- findings the reviewer reported that were rejected as wrong or as nits: false
  positives are as diagnostic as misses

One anecdote is not evidence for changing an invariant. A repeated pattern is.

## The loop

### 1. Record the miss

For each escaped defect, fill `workflow/templates/escaped-defect.md` before or
with the fix. Storage: **personal stack → obvault** (bounded shadow only);
**work stack → brain**. Reusable cases also append
`workflow/self-improvement/reviewer-eval-corpus.md`.

Required fields (see template):

- the diff and commit the reviewer passed
- the defect, sourced `file:line`
- **what the reviewer would have had to do to find it**: which file it had to open,
  which lens would have surfaced it, which retrieval step was skipped
- whether an existing lens covered it and was not run, or no lens covered it
- bucket + action

That third item is the whole point. "Missed a precedence bug" is actionable.
"Missed a bug" is not.

### 2. Classify

Every miss lands in exactly one bucket, and the bucket decides the response:

| Bucket | Meaning | Response |
| --- | --- | --- |
| `lens_existed_not_run` | A lens covered it; the agent skipped it | Tighten the output contract so skipping is visible. No new lens. |
| `retrieval_gap` | The deciding code was never opened | Strengthen deciding-code / retrieval heuristic for that shape. |
| `lens_missing` | No lens asks this question | Candidate for a new lens. See the budget below. |
| `evidence_bar` | Found it, discarded it as unprovable | Check the bar is calibrated, not that it is too high. |
| `out_of_scope` | Not the reviewer's job (product decision, taste) | `no_op`. Record so it is not re-litigated. |

### 3. The lens budget

Lenses are capped. The cap is the mechanism that stops checklist rot.

- **Maximum 8 lenses.** Adding a 9th requires merging or dropping one.
- A new lens must be **general**: it must name a *class* of defect, phrased as a
  question that applies to changes the agent has never seen. "Check the timezone
  header order" is an instance. "When two sources supply one value, which wins?" is
  a lens.
- A new lens must be justified by **at least two independent misses**. One miss
  becomes an eval case, not a lens.
- Merge aggressively. Two lenses that would fire on the same diffs are one lens.

### 4. Eval corpus

Every miss becomes a regression case, and this corpus is the real asset: it is what
lets you tell an improvement from a rationalization.

Each case holds: the diff (or commit range), the defect with its location, and the
verdict a correct review would produce. Cases are cheap; keep them all, including
the ones no lens covers.

Before accepting any change to the reviewer:

- **held-in**: it must catch the misses that motivated it
- **held-out**: it must not regress the cases it already passed, and must not start
  reporting findings on the clean diffs in the corpus

A change that fixes the held-in cases and adds false positives on held-out ones is
a regression. Reject it and log why.

### 5. Log rejections

Rejected candidates are recorded with the reason and the evidence, so later runs do
not re-propose them. This file is also where "sounds good, measured as useless"
lives: multiple personas (no measured gain), LLM self-rated severity (miscalibrated,
overconfident), re-sweeping the same diff for more findings (recall up a little,
false positives up a lot).

## Candidate outcomes

Each candidate ends as exactly one of:

- `no_op` — weak, isolated, stale, out of scope, or already covered
- `eval_case` — added to the corpus, no prompt change
- `retrieval_change` — deciding-code / Phase 1 gains a specific thing to open
- `lens_change` — a lens added, merged, or reworded, within budget
- `contract_change` — the output contract changes so a skipped step becomes visible
- `rejected` — tried, regressed held-out, logged with evidence

Default to `eval_case`. Most misses do not justify touching the prompt, and the
corpus is what makes the next change measurable.

## What stays out of the loop

- The evidence bar does not get lowered to catch more. A reviewer that reports
  maybes gets ignored, which is a total loss of value, not a partial one.
- No numeric self-confidence. Verbalized LLM confidence is measurably
  miscalibrated; the evidence in a finding is the signal.
- No instance-specific rules in the prompt. They belong in the corpus.

## Running it

This loop is not automatic and should not be. Run it when escaped defects
accumulate — after a batch of PRs, or when a miss is bad enough to warrant it. A
loop that fires on every PR spends more than it returns and pressures the agent
toward prompt growth, which is the failure mode.

Report, per run: misses recorded, bucket counts, candidates and their outcomes,
held-in/held-out results for anything accepted, and current lens count against the
cap.
