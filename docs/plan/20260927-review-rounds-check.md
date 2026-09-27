# Implemented: review round machine enforced on the workflow ledger

## Metadata
- Archived: 2026-09-27
- Source plan: `PLAN.md` — Suite audit 1 — la machine de review T/D/F vérifiée mécaniquement sur le ledger
- Source plan SHA-256: `265116d64717e0e2c578a31ad6ed0adc042e5ac4da99654b2d0cdd4cf0104a08`
- Status: IMPLEMENTED
- Commit / branch: `feat/review-rounds-check`, stacked on `refactor/lean-context-t4` (base `fdcf368`); not pushed
- Workflow initiative: `review-rounds-check` (blocked at F1, D budget spent), `review-rounds-check-r2` (F1 clean, then closed as documented `blocked`: the archive was logged as `file_changed` after the validated F1, which the completion profile and the new machine correctly refuse to complete without a fresh review)

## Outcome
- `review_completed` accepts the optional pair `review_round` (`T1`, `T2`, `D1`, `D2`, `FD`, `F1`, `F2`) and `round_outcome` (`clean`, `findings`, `widening`). The two fields come together, and only on v2 events. The historical integer `round` stays valid.
- `scripts/lib/review-rounds.jq` applies `workflow/skills/review-rounds.md` to tagged `plan-implement` runs. `scripts/workflow-event validate` runs it after the structural loop. `append` runs it on the candidate ledger before writing. A refused append leaves the ledger and the active-run pointer intact, and `blocked` is always appendable.
- The machine:
  - activates at the first tagged review; untagged reviews after it are refused;
  - checks the transition table; each tag is used at most once, and a third D unit is impossible by construction;
  - uses aggregated closure. T and F rounds need a `code_diff` adversary in their window. A `clean` round needs a non-`BLOCK` status and adversaries that are `GO`/`GO WITH NOTES` with `accepted_findings: []`;
  - refuses a `code_diff` adversary after the closing clean F;
  - lets any `completed` pass only after a clean F1 or F2.
- On every ledger, a non-canonical envelope is refused: `schema_version` must be absent, `1` or `2`, and `event` must be exactly `[a-z_]+` (anchors `\A…\z`).
- Every error names the round, its rank, the admitted next rounds and the remediation.
- Delivery:
  - the scaffold (`scripts/deploy-workflow` FILES and `.git/info/exclude`) ships the filter;
  - the `workflow-ledger-check` fingerprint covers it, computed from the selected `--workflow-event` binary;
  - the contract text is in `review-rounds.md`, `implementation-loop.md` 13b and `events.md`.
- Dogfood: both review runs of this plan were tagged. The machine refused an FD beyond the spent D budget on the first run.

## Context
- `scripts/workflow-event` validates through the bash loop of `validate_ledger_file`, not `batch_ledger`. Bash `$(…)` strips trailing newlines and NUL bytes from the fields it reads, whereas jq sees them.
- In Oniguruma, `$` matches before a final newline; only `\z` anchors the absolute end.
- 154 real ledgers: 0 non-canonical envelopes, 0 tagged reviews before this plan.

## Decisions
### Canonical envelope allow-list instead of mimicking bash normalization
- Context: F1 found a `"2\n"` bypass, and plan pass R8 then found `"2\u0000"`.
- Choice: refuse any envelope outside a closed form, on every ledger.
- Rejected options: strip newlines and NUL bytes the way bash does, a denylist that did not converge (same lesson as the rtk allow-list of T4).
- Rationale: closed by construction; no real ledger is affected.
- Consequences: a hand-edited ledger with an exotic `schema_version` or event name now fails validation.

### Separate filter shared by both CLI paths
- Context: validate and append must agree.
- Choice: one `review-rounds.jq`, fed the file on validate and the candidate (history + new line) on append.
- Rationale: one source; the candidate read fails closed.

### Out of reach, kept as prose
- Ship budget inheritance (`ship.md`): ship runs are not checked.
- The D-round adversary after a folded high finding: severity is not in the ledger.
- A mis-declared `round_outcome`: the check prevents impossible sequences, not a wrong outcome.

## Accepted Drift
- Original plan/spec: D1 widening → next unspent T, else blocked (`review-rounds.md:24-26`).
- Implemented reality: D1 widening → blocked.
- Why accepted: in a `plan-implement` run, D1 always follows T2, so no T remains; the divergence is unreachable.
- Original plan/spec: `tests/ship-order-smoke.sh` absent from Scope.
- Implemented reality: its pin follows the replaced sentence of `review-rounds.md`, at the same assertion strength.
- Why accepted: a ripple of AC6, added to Scope during T1.

## Validation Evidence
- command: `bash tests/workflow-event-smoke.sh`, `tests/workflow-scaffold-smoke.sh`, `tests/workflow-ledger-check-smoke.sh`, `tests/ship-order-smoke.sh`
  - result: ok. Every new rule is covered by a fixture, and each was mutation-checked: 35 mutations, and the only survivor (accepted findings on a GO WITH NOTES adversary) led to the `rr-clean-accepted` fixture.
- command: `scripts/workflow-ledger-check --full`
  - result: ok=114 quarantined=12 stale=0 failed=0
- command: `scripts/verify-agentic-infra core` and `full`
  - result: 27/27 and 81/81
- command: `scripts/workflow-context-budget`, `scripts/token-bench --check`
  - result: ok; plan-implement +1.42 % against the baseline, within tolerance
- Reviews:
  - Plan: 9 cross-family passes (`gpt-6-astra`), the last one READY.
  - Code, run 1: T1, T2, D1, D2, F1; F1 had findings with two D units spent → blocked.
  - Code, run 2: T1 clean, then F1 clean. Logic GO, Spec GO. The adversary ran via `pi-review-hunter` with `openai-codex/gpt-6-astra` (capture `75d2fccf…`), after the `codex exec` pass was stopped because of rate issues.
