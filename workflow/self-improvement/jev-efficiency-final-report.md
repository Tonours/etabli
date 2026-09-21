# Jev route-capsule efficiency result

Status: accepted by the frozen comparator and terminal three-repeat gate, then
promoted into the installed Pi runtime after explicit authorization.

## Scope

The candidate adds one typed `jev-1.13.0` route judgment before eligible
planning, implementation, and review work. Protected and private-inline cases
bypass Jev. Deterministic code retains permissions, PLAN state, mutation,
fallback, comparison, and promotion authority.

The validation population is adaptive and non-sealed. This result proves the
bounded campaign outcome; it is not an untouched external-generalization
claim.

The frozen population contains three distinct held-in tasks, three distinct
held-out tasks, and one safety task across all seven required categories. The
campaign ledger records exactly four offline hypotheses and both allowed
live-candidate slots. The first result is retained as historical evidence; the
second result binds the corrected candidate and is the terminal comparison.

## Frozen evidence

- Manifest: `45ceb68e...bf76`
- Evaluator bundle: `6b7fb945...be8a`
- Population: `c299d1e4...2bba`
- Baseline artifact: `272814c7...4ada`
- Candidate artifact: `04656055...3fa8`
- Baseline result: `7cf46fca...d8336`
- Candidate result: `ebc3d687...d2716`
- Runtime: Pi 0.86.1, `openai-codex/gpt-6-astra`, medium, retry disabled

## Result

| Metric | Baseline | Candidate |
| --- | ---: | ---: |
| Traditional-LLM total tokens | 1,472,609 | 889,124 |
| Provider price telemetry | 4.675322 USD | 3.260280 USD |
| Jev calls | 0 | 9 |
| Jev tokens | 0 | 4,338 |
| Protected cases passed | 3/3 | 3/3 |

Traditional-LLM tokens decreased by 39.623%. Per-repetition reductions were
45.050%, 34.080%, and 39.945%; every repetition clears the 30% target. The 50%
stretch target is not met. The pass vector remained
`pass, pass, fail, fail, pass, pass, pass`, so the candidate introduced no
held-in, held-out, or safety regression and did not hide the two existing
baseline failures.

Jev produced 9 accepted decisions in 3,328 ms with zero abstentions,
escalations, or retries. Provider token usage was complete. Jev cost telemetry
was unavailable and is therefore reported as unknown, never as zero.

## Safety and autonomy evidence

- The ignored `.workflow/` tree contains the private population, prompts,
  traces, provider receipts, and run results; no file below it is tracked.
- An exact-key scan confirmed that the configured TypeSafe credential appears
  in neither the public candidate surfaces nor the private candidate output.
- The child LLM environment removes `TYPESAFE_API_KEY`; protected and
  private-inline tasks perform the exact candidate-off invocation.
- Candidate eligibility is code-owned and limited to planning,
  implementation, and review. Jev output cannot grant write permission,
  change PLAN status, enable a candidate, mutate, compare, promote, or deploy.
- Deterministic tests cover closed provider/READY/adversary gates, receipt-bound
  escalation continuation, fabricated escalation state, early
  runtime activation, malformed usage, provider failure, abstention, unsafe
  fallback, fifth-hypothesis rejection, protected regression, quality
  regression, rejection-to-rollback, and accepted completion readiness.
- The completed path is fingerprint-bound from observation through typed Jev
  abstention, traditional-LLM escalation, deduplication, READY plan,
  adversary GO, verified implementation, paired comparison, and final
  three-repeat acceptance. The escalation coordinator preserves the original
  Jev abstention and cannot relabel it as Jev diagnostic maturity.

## Installed-runtime promotion

The authorized promotion is enforced by
`workflow/runtime/jev-route-capsule-policy.json` and the separately hashed
`workflow/runtime/jev-route-capsule-promotion.json`. At every load, the runtime
recomputes the promoted source hashes and verifies the accepted candidate,
comparison receipt, stable quality vector, per-repetition target, and protected
preservation. Any manifest, receipt binding, or source drift fails closed to the
deterministic route contract. The policy permits the evaluated
planning/implementation/review route set plus the separately validated
`plan-implement` activation, keeps protected routes as bypasses, and fixes
`max_retries` at zero. The
legacy semantic route policy is disabled so one prompt cannot cause two Jev
route calls. The installed Pi extension directory is a managed link to this
checkout, so `pi/extensions/jev-route-capsule-runtime.ts` is the active runtime
source.

The deterministic route maps each eligible request to exactly one expected Jev
category; a conflicting Jev category is recorded as `route_mismatch` and is not
injected. Post-promotion validation is green: focused promotion/router/loader
tests 39/39, Pi 320/320, core 22/22, Jev smoke, Pi typecheck, and diff check. A live
`jev-1.13.0` canary returned `planning` in 735 ms with 434 input and 49 output
tokens, exactly one call, zero retries, and an accepted capsule. A separate Pi
0.86.1 JSON-mode run using the installed extension link and the retry-disabled
agent profile emitted `etabli.jev-route-capsule` and completed an assistant
turn. The rollback test proves that switching the promotion policy to
`mode: disabled` performs zero Jev calls while retaining the deterministic route
contract. No commit, push, deployment, or production mutation was performed.

## Plan-implement activation

`jev-route-capsule-v3` adds a dedicated `plan_implementation` Choice outcome
and compiled capsule. It explicitly preserves the phase boundary: a DRAFT or
CHALLENGED plan cannot authorize implementation, and the actual root plan must
be READY before deterministic mutation gates can allow code changes. A Jev
answer in any neighboring category is a `route_mismatch` and falls back without
capsule injection.

The public activation receipt binds three synthetic live canaries: explicit
skill use, a natural-language plan-and-build request, and an active draft-plan
cycle. All three selected `plan_implementation` with confidence 1.00, 0.99,
and 1.00, using three calls, zero retries, 1,721 Jev tokens, and 1,264 ms total
latency. The v2 paired comparison remains the evidence for the previously
evaluated routes. Traditional-LLM runtime savings for `plan-implement` are
explicitly `not_measured`; activation is not presented as an extension of the
39.623% result.
