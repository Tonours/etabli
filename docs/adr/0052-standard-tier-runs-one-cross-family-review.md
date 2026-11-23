---
status: accepted
date: 2026-11-23
tags: [workflow, review, tiers]
affected_components: [workflow/skills/implementation-loop.md, workflow/skills/review.md, workflow/skills/review-rounds.md, workflow/skills/adversary.md, workflow/spec.md, workflow/templates/plan-archive.md]
---

# Standard tier runs one cross-family review

A standard run keeps its plan and READY gate but drops the plan adversary and
the code-diff adversary. Steps 13 and 13b become one fresh-context review of the
cumulative patch (`workflow/skills/review.md` § Standard review): one Logic
hunter on a non-author model family, Spec in the parent recorded
`spec: parent`, and the Threat hunter on the same route when its trigger fires.
The route is the author-family inversion route when one exists. Otherwise, or
after a sentinel, it is the next non-author route of the cross-harness pool,
recorded `runner: pool-route`. The parent's same-family runner is never used
while an eligible route is untried. The deadline is 1800 s, so a timeout meets
the 30-minute technical-unavailability bar. When every route is unavailable, one
same-family Logic hunter is labeled `same-family` and recorded
`cross_model: unavailable (<category>)`. The double-sample fallback is deleted.
The budget is T1, then one D1 over the whole cumulative patch. A run still
blocking after D1, a fix on a high-risk surface, or a review due with both
rounds spent upgrades the run to high-risk. That means a plan adversary first,
then a full tour as the next unspent T. One counter spans upgrades. High-risk,
bounded fix and small are unchanged.

Context. Standard is the default planned tier, yet it stacked four passes plus
re-review rounds, while a bounded fix on the same kind of surface paid one
review. The detection value of the extra passes was never measured. The
escaped-defect baseline on 2026-11-23 holds 19 records over the two memory
vaults:

- 6 personal records, all at `tier: high-risk`. Five were found by CI and one
  by an independent review.
- 13 work records: 8 at `tier: unknown` and 5 with no tier field.

None is at standard or bounded-fix. Plan archives carried no tier, so no
denominator existed.

Replay (`AGENTS.md` § Workflow). The three reachable personal records went once
through the new single Logic hunter on its inversion route. The cases were
recorded escaped defects A, B and C, plus one control D. The hit rate was
**0/3**, and the control raised no finding. This is the main caveat: all three
are high-risk changes that also escaped the full machine. The replay therefore
does not separate one review from four passes. It does show that the single
Logic hunter misses this defect class. Case B had been caught by an independent
review. The dated count below is the real test, and the restore criterion is
what limits the damage.

Rejected options:

- Keeping the code-diff adversary and dropping the hunters. The hunter carries
  the lens and the deciding-code table that `GO` needs, and the replay rule is
  built on it.
- Cutting high-risk too. Every personal record is high-risk and escaped the full
  machine, which argues for project constraints there, not fewer passes.
- Measuring for four weeks before changing anything. No standard record exists
  to compare against, and the bounded fix has used this shape since 2026-11-06.
- Keeping the double-sample as the fallback. Two same-family passes cost more
  than the one labeled pass a bounded fix already accepts.
- A counting script, which would be a new surface (`AGENTS.md` § Growth). One
  grep does the job.

Measure:

- Denominator. Every archive now carries
  `- Tier: <small|bounded-fix|standard|high-risk>; review: <self|single|full>`.
  `standard; review: single` is the new journey and `standard; review: full`
  the old one. A standard archive without the line has exposure `unknown` and
  stays out of the count.
- Cohort. Archives with `Tier: standard` and `review: single`, `Archived:` on or
  after this ADR's merge date. Escaped-defect records count by the same cohort.
  A record whose change has no such archive counts as `unknown` exposure.
- Counting command, run per vault (`<vault>` is the memory vault root):
  `grep -rhIA12 '^escaped-defect:' <vault> | grep -E 'tier:' | sort | uniq -c`.
  The denominator is the archives listed by
  `grep -rl '^- Tier: standard; review: single' docs/plan/ | xargs grep -H '^- Archived:'`
  whose `Archived:` date is on or after the merge date.
- Attribution. A record counts against a removed pass only when the owner judges
  at the review date, from its `defect` and `would_have_needed`, that the plan
  adversary, the Spec hunter or the code-diff adversary would have caught it.
  The tally is manual and only aggregate counts are written down.
- Restore criterion. Two or more cohort records the owner attributes to the same
  removed pass restore that pass at standard. Fewer than five cohort archives in
  the window make the count inconclusive and extend it by four weeks. Otherwise
  the next cut candidates may open their own plan.

Durable exception. `durable/` keeps its own four-axis review until its own plan
changes it. `workflow/spec.md` § Durable runs names it on the same line.

- Review date: 2026-12-21. Run the count above and apply the restore criterion.
