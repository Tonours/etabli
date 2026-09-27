## Phase 4 — deterministic rank

Score each shortlist card from 0–5 per criterion **only when the criterion has
evidence**. Do not score proof strength alone: apply these observable bands
within the evidence window. `N/A` means missing or unresolved contradictory
evidence; `0` is reserved for direct negative evidence or an explicit numeric
band below. Any scored criterion `N/A` moves the item to `watchlist`; never
average it away. Optional context fields do not enter the score. Rank modes
separately and keep `emergence_signal`, `market_proof`, and `founder_fit` as separate fields.

SaaS bands: recurring pain (`0` one-off/negative, `1` one dated discovery-only
signal, `2` one repeated indirect signal, `3` at least two direct dated signals,
`4` weekly/monthly repeat or costly workaround, `5` daily/revenue/compliance
impact); buyer budget (`0` explicit refusal/no budget for this job, `1`
quantified recurring time cost plus identified payer, `2` observed payment or
billed hours for the same job by that payer, `3` observed repeat spend/renewal
for that job, `4` explicit allocated budget from its decision-maker for the
proposed outcome, `5` actual paid pilot/order for the proposed solution).
A listed incumbent price alone is `N/A`; it cannot establish buyer budget.
Keep time-cost estimates, existing spending and proposed-solution commitment
separate even when selecting the strongest supported band.

Access (`0` no lawful route, `1` generic group, `2` named active public group,
`3` founder has a direct route, `4` concrete ten-conversation plan in 14 days,
`5` ten conversations or a pilot observed); wedge (`0` forbidden/clone, `1`
decorative layer, `2` broad repackaging, `3` narrow job, `4` measurable output,
`5` differentiated workflow/data/access validated); founder stack fit (`0`
forbidden/mismatch, `1` unfamiliar stack, `2` feasible, `3` known stack, `4`
reusable asset or shortcut, `5` existing component plus reachable user).
Emergence is reported separately and never changes score or eligibility.

Ecommerce bands:

- **Demand proof:** `0` direct negative/no intent; `1` one discovery-only signal;
  `2` one dated indirect signal; `3` two independent demand signals; `4` those
  two plus an observed request/return pain; `5` paid, preorder, or repeat
  purchase observed.
- **Contribution margin:** `0` ≤0%; `1` 0% < margin < 10%; `2` 10% ≤ margin <
  20%; `3` 20% ≤ margin < 30%; `4` 30% ≤ margin < 50%; `5` ≥50%.
- **Time to first payout:** `0` >90 days; `1` 61–90; `2` 31–60; `3` 15–30;
  `4` 8–14; `5` ≤7 days.
- **Initial capital:** measure `r = cash_at_risk_in_cap_currency /
hypothetical_test_cap_cap`; `0` r >100%; `1` 75% ≤ r ≤100%; `2` 50% ≤ r <
  75%; `3` 25% ≤ r < 50%; `4` 0% < r < 25%; `5` r = 0%.
- **Fulfilment/legal risk:** `0` direct hard blocker; `1` high; `2` material;
  `3` manageable; `4` low; `5` no material issue after current checks;
  unknown or unresolved is `N/A`.
- **Differentiation:** `0` commodity/copy; `1` generic variation; `2` minor
  niche; `3` clear job/audience; `4` proprietary asset, supply, or access;
  `5` defensible advantage or validated preference.

Compute a 0–100 `weighted_score = sum(score / 5 * weight)` across the named
percentage-point weights, report to two decimals, and state the evidence IDs
behind each score. A card is
`complete evidence` only when every mandatory fact for its mode, independence
gate, access route, applicable cost/tax field, counter-search and score
criterion is present with no unresolved gap or material contradiction. Optional
context may remain unknown; an honest `zero` counter-search is completed work.

For multiple evidence items on one criterion, apply this decision order: first
mark a material contradiction as `N/A`; next use `0` when direct negative
evidence is uncontested; otherwise choose the strongest applicable positive
rubric level (5 down to 1). If several items share that level, choose the newest
ISO-dated item, then the lexicographically smallest `evidence_id`. Supporting
items add to `evidence_count` but do not change the criterion score. This fixed
selection rule is the only aggregation rule.

Count `evidence_count` as unique, opened `evidence_id`s after removing copied
duplicates; count independent identities separately for the independence gate.
Do not normalize `evidence_count` into the score. Dispositions
(`watchlist`/`rejected`) follow the single disposition rule in
`references/queries.md`; record the missing fact and next query/validation
step, or `next_step: unknown`. Apply that rule before ranking, so `N/A` never
receives a score.

SaaS weights: recurring pain 30%, buyer budget 20%, access 20%, wedge 15%,
founder stack fit 15%.

Ecommerce weights: demand proof 25%, contribution margin 25%, time to cash 20%,
initial capital 15%, fulfillment/legal risk 10%, differentiation 5%.

Sort first by `weighted_score` descending. Then use this tie-break order:
complete evidence > evidence count > stable `candidate_slug` (ascending).
Regulatory and safety blockers are gates, not positive score.
