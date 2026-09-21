# Jev plan-implement efficiency result

Status: **rejected / non-comparable** on 2026-09-21.

The frozen baseline completed three repetitions of all three route-specific
scenarios. Every baseline cell passed its exact worktree, terminal ledger and
safety oracle. Traditional-LLM totals were 1,560,444, 1,526,973 and 1,642,388
tokens, or 4,729,805 total. Provider receipts exposed an estimated 8.75845 USD;
because execution used the user's subscription, incremental billed cost is
`unknown`, not asserted as zero.

The first candidate cell was not comparable. Jev selected
`plan_implementation` with confidence 1.00, one call, 741 tokens and zero
retries. The experimental runner then appended the capsule to the user prompt
before deterministic routing. Capsule wording triggered the `adversary` route,
so the candidate did not implement, archive or complete its ledger. Savings are
therefore `null`; the run cannot inherit the earlier general 39.623% result.

The corrected evaluator now injects the capsule with Pi's
`--append-system-prompt`, after route selection, and has a new bundle hash. It
was not run against the old baseline because that would violate evaluator and
manifest comparability.

Three explicit-live self-improvement controller checks each made one
retry-disabled Jev call and zero traditional-LLM calls. All three abstained as
`uncertain`; `propose_reviewed` remains disabled. The safe policy result is to
remove only `plan-implement` from `eligible_routes`, preserve the other measured
routes, and retain deterministic fallback.

Development usage exceeded the original 21-call allowance: 35 traditional-LLM
executions were observed or started across invalid fixture pilots, interrupted
campaigns, canaries and the terminal run. This is reported as a budget overrun,
not hidden inside the final campaign. All invalid and private provider evidence
remains under ignored `.workflow/` paths.

Machine-readable aggregate: `workflow/self-improvement/jev-plan-implement-result.json`.
