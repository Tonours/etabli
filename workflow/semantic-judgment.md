# Semantic route decisions

Etabli uses TypeSafe Jev as a bounded semantic route selector in the local Pi workflow. Code remains authoritative for permissions, destructive or external actions, actual `PLAN.md` state, READY and mutation guards, validation, and provider failover.

Modes:

- `disabled`: no provider request and no receipt.
- `shadow`: evaluate and record the answer without changing the deterministic route.
- `enforced`: accept an eligible Jev route only when the checked-in promotion manifest is valid and the answer passes the frozen confidence and top-two probability-margin thresholds.
- `advisory`: reserved and rejected by the runtime.

The checked-in policy uses `enforced`. `ETABLI_SEMANTIC_MODE=shadow` or `disabled` provides an immediate local rollback. Enforced startup validates the pinned model, route set, question and runtime fingerprints, thresholds, representative corpus fingerprint, unique-case count, repetitions, accuracy, accepted coverage, semantic-override quality, protected-route safety, prediction stability, Brier score, expected calibration error, provider-error rate, input cost, and p95 latency. Any mismatch rejects the promotion configuration; provider errors or uncertain answers during a turn abstain to deterministic routing.

The semantic Choice distinguishes read-only `answer` from bounded `direct-edit`, because both map to the public `answer` workflow route with different write semantics. Local-write decisions use stricter confidence and margin thresholds than read-only decisions. Jev may select a workflow route and its coherent route profile, but these boundaries stay in code:

- a deterministic `ops-stop`, `ci-fix`, `linear-ticket-create`, or `linear-work` route cannot be overridden;
- Jev cannot select those protected routes as authoritative alternatives;
- `implement` requires the actual local plan status to be `READY`;
- any active `DRAFT`, `CHALLENGED`, or `READY` plan blocks semantic `direct-edit`; `implement` is eligible only for `READY`;
- slash commands, tool mutation guards, check-freeze, and external-action checkpoints do not depend on Jev.

The promotion evidence in `workflow/runtime/jev-route-promotion.json` comes from 90 live observations: 30 unique cases repeated three times over `tests/fixtures/jev-shadow/live-route-corpus.json`. It records 93.3% raw route accuracy, 100% accuracy among threshold-accepted decisions, 63.3% automatic coverage, 10 semantic-override cases with 100% raw and accepted accuracy, 60% accepted override coverage, 100% protected-route preservation, 100% prediction stability, Brier score `0.102108`, expected calibration error `0.045556`, no provider errors, 432 ms p95 latency, and `$0.003393` measured input cost. The six wrong observations were stable across repeats and rejected by thresholds or protected-route fallback. These measurements describe this frozen corpus, model, question, and runtime; they are not a general quality claim.

The TypeSafe adapter pins `jev-1.13.0`, reads `TYPESAFE_API_KEY` only from the process environment, retries only 429/529 and network failures within a bounded budget, and validates every response field. State includes only a length-bounded normalized user intent and plan status and is rejected before network I/O when it resembles a credential. Receipts contain hashes, typed outputs, selected-source provenance, latency, and usage; they never contain prompts, API keys, or raw provider payloads.

Jev runs only inside the current local workflow. Pi awaits enforced decisions before recording the turn route. The local CLI provides health, one-shot evaluation, synthetic replay, and explicit live calibration. There is no HTTP listener, remote service, container image, or deployment path.
