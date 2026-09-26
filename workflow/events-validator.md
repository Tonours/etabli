# Workflow Events Validator Internals

Validator and writer internals for `.workflow/<slug>/events.jsonl`; the
agent-facing contract is `workflow/events.md`.

## Writer integrity

The writer validates the ledger and re-checks terminal state while the lock is
held. Program event IDs are idempotent; a reused ID with different content is
rejected.

Native internal append execution proves that its actual `lockf`/`flock` parent
is the trusted system executable and was invoked on the fixed descriptor `9`
from the canonical run directory. That descriptor must resolve to the current
canonical `events.lock` inode, which is then separately proven locked.
Executable, directory, arguments, descriptor, and lock state are read only
through fixed system binaries plus `/proc` on Linux or `lsof` on macOS;
caller-controlled `PATH` helpers are not authoritative. Descriptor locking
keeps the lock file and preserves kernel lock ordering. Merely opening the
canonical file on another descriptor, replacing its pathname, placing
`_append-locked` beneath an unrelated lock process, or minting a caller-owned
JSON marker confers no authority; missing process proof fails closed. The
writer rechecks contention and FD-to-inode identity immediately before the
append syscall. This is a cooperative-writer integrity boundary, not a security
boundary against a same-UID actor that can mutate files or processes inside
that final syscall interval.

For a schema-v2 run that has ever declared the `plan-implement` route,
`completed` is also preflighted while holding that lock: the writer validates
an exact temporary candidate with `--profile autonomous-completed` before it
appends the same terminal line. Missing evidence therefore leaves the canonical
ledger and active-run pointer untouched. Schema-v1 and non-`plan-implement`
ledgers retain structural completion compatibility.

For consecutive program events, a disposable checksum/count cache avoids
re-running the historical schema scan on every unit update. A matching cache
still does not skip `workflow-measurement-integrity` when the ledger contains
measurement events. A missing or mismatched cache forces full validation; it
never stores program state or replaces `events.jsonl`.

## Program events

Every program event includes `event_id`, `program_id`, `manifest_sha256`,
`unit_id`, `attempt_id`, and `emitter:{id,role:"coordinator"}`. Workers never
append these events directly.

| Type | Detail convention |
| --- | --- |
| `program_initialized` | common program identity + `{manifest_path, runtime_capability:proxy_supported | blocked}` |
| `program_unit_started` | common program identity + `{worker:{id,model_family,worktree,branch,head}, files, tools}` |
| `program_unit_result` | common program identity + `{worker_id, head, status:passed | failed, artifact:{path,sha256}}` |
| `program_unit_verdict` | common program identity + `{verifier:{id,model_family}, head, verdict:passed | failed, evidence:{path,sha256}}` |
| `program_unit_head_changed` | common program identity + `{worker_id, previous_head, new_head}` |
| `program_unit_retry` | common program identity + `{previous_attempt_id, reason}` |
| `program_unit_reconciled` | common program identity + `{zombie_attempt_id, disposition:ignored | accepted, reason}` |

## Event semantics

A `harness_proposal` whose `candidate` matches a prior
`harness_candidate_rejected.candidate` or a rejected
`harness_validation_completed.candidate` must list it in `supersedes`; enforced
by `scripts/workflow-supersession-check`. <!-- etabli-only -->

A `runtime_receipt` is a non-cryptographic parent-process observation binding a
ledger assertion to a hashed subject (path or command) and exit; it stores only
allowlisted hashes, never raw output or secret-bearing text.

Private comparator inputs and detailed run evidence are not ledger payloads for
the public repository. Store them in Obvault outside ForestAdmin and in Brain
inside ForestAdmin; keep Etabli records limited to redacted references,
fingerprints and aggregate verdicts.

`outcome_metric` accepts additive optional runtime fields in either branch
(validated when present, ignored when absent): `runtime` (provider/runtime id
string), `turn_count`, `auto_continue_count`, `token_estimate`, `wall_clock_ms`,
`success_kind` (`run_terminal`|`task_grader`), `grader_success`,
`participant_usage` (`[{id,role?,input_tokens,output_tokens,total_tokens}]`
whose totals must sum to `total_tokens` when measured), `batch_wall_clock_ms`,
`batch_started_at`, `batch_terminal_at` (ISO-8601 Z). Prefer `total_tokens` =
all model participants; prefer `batch_wall_clock_ms` = batch makespan for
verified throughput. No producer ships since T2; the event stays readable for existing ledgers.
Retrospect counts usage coverage only when `measured:true` has a complete valid
usage tuple: non-negative integer input/output/total tokens, non-negative
integer tool calls and non-negative elapsed time, with total at least input plus
output. A quality-only measured event is reported separately; partial or
malformed usage is reported as invalid and does not suppress native usage
recovery.

`runtime_run_attached` links adapter-owned evidence to the Etabli run; it does
not make `.pi/workflows/<run-id>/` a second planning or progress source of
truth. Its `state_path` must be exactly `.pi/workflows/<run_id>`, its status must
match a pi-workflow run status, and unavailable usage is represented by
`usage_measured:false` rather than zero-valued token fields.

`harness_validation_completed` is only for a real comparative run over the
same baseline/candidate population in each held-in and held-out split. Each
split uses `{baseline:{population,passed,total},candidate:{population,passed,total}}`.
Counts
are non-negative integers, totals are positive and match within each split,
`passed` cannot exceed `total`, and each result names the same non-empty stable
population identifier as its baseline/candidate peer. An `accepted` verdict
requires the manifest-frozen quality, efficiency, or reliability objective and
held-out non-regression. Efficiency and reliability also freeze the measurement
population in the objective; both result measurements must match it. Comparative
negative results use `rejected`; candidates rejected before a comparable run
keep using `harness_candidate_rejected`. Metrics report per-candidate
percentage-point deltas and never average heterogeneous suites into a global
improvement score.

Strict evaluator provenance binds the declared evaluator entry path to exactly
one bundle member and verifies both the entry file SHA-256 and the full bundle
SHA-256 before accepting a comparator result.

Strict `schema_version: 2` comparisons additionally bind both result documents
to the exact manifest bytes and evaluator-bundle SHA-256. The bundle lists the
runner, libraries and oracles used by the comparison; changing any listed file
or the manifest makes the evidence non-comparable. The comparator records
held-in, held-out and safety pass-to-fail transitions by task ID, and rejects a
baseline that already contains a failed safety case. The decision event must
also carry a relative `comparison_path` and its `comparison_sha256`; the
validator reads that immutable comparator output and checks its status, verdict,
provenance and artifact fingerprints before accepting the decision. The
`autonomous-completed-strict` terminal profile now fails closed on any
`harness_validation_completed`: the comparator chain was removed in T2.

`multi_execution_completed` requires a non-empty model ID whose prefix matches
its declared family. `verdict` is `accepted | degraded | blocked |
rollback_to_opt_in`; `fallback_status` is `none | degraded | blocked`;
`usage:{measured,...}`. When `usage.measured` is true,
non-negative `input_tokens`, `output_tokens`, `total_tokens`, and `elapsed_ms`
are required; `total_tokens` cannot be lower than input plus output.

Historical events without `protocol_version` remain valid. Protocol v2 adds
`trigger`, `strategy`, deduplicated bounded `signals`, `rounds`, `claim_count`,
`disagreement_count`, `stop_reason`, numeric requested `budget`, and measured or
explicitly unmeasured `stage_usage` for first pass, rebuttal, and adjudication.
Adaptive v2 evidence needs at least one signal. Scouts cannot rebut or judge;
an adjudication round requires a named adjudicator. If claims or any measured
stage/total output exceed the requested budget, only `stop_reason: budget_cap`
with a `degraded` or `blocked` verdict validates; an accepted overage is
rejected. V2 budgets are canonical rather than caller-selected: scout uses
`600/0/0/600` and council uses `1800/700/650/3500` for
first-pass/rebuttal/adjudication/total output, both with six claims. The
validator also binds adaptive signals to the selected strategy, requires unique
participant IDs and models, and validates the participant count per strategy:
one for a scout without fallback, two for a council without fallback. It also rejects
contradictions between disagreement counts, fallback, verdict, stop reason,
and executed rounds. `fallback_status` carries replacement degradation, so a
degraded fallback run keeps its real resolution reason such as `agreement`,
`rebuttal_resolved`, or `adjudicated` instead of overwriting it with
`stop_reason: degraded`.

## Measurement recovery

Historical usage recovery is an evidence overlay, not a rewrite. A single
`outcome_measurement_population` pins the exact terminal-run manifest and its
content fingerprints: `{population_id, manifest_sha256, terminal_runs, targets:[{target_run, target_ledger_sha256, target_terminal, target_terminal_event_sha256, target_outcome_event_sha256, baseline_measured, baseline_usage_measured}]}`.
`outcome_measurement_imported` detail:
`{population_id, import_id, target_run, target fingerprints, source_adapter:"codex", source_scope:"primary_session_window", selection:"shortest_enclosing_primary_session", session_fingerprint, window/sample bounds, sample_count, success, input_tokens, output_tokens, total_tokens, tool_calls, elapsed_ms}`.
Each `outcome_measurement_imported` must be a unique
member of exactly one matching population and carries only aggregate usage,
time bounds, counts, and an opaque SHA-256 session fingerprint. The recovery
helper reads only session envelopes, cumulative token counters, timestamps,
user-message boundaries, and tool-call types; it never persists prompts,
responses, reasoning, raw session IDs, or filesystem paths. It accepts only a
primary session that fully encloses a run, has a baseline no older than 120
seconds, has monotone counters, includes a sample inside the run, has a
post-terminal sample within 120 seconds, has no
new user message before that final sample, and does not overlap another
accepted token slice.
Runs under 60 seconds, ambiguous sessions, counter resets, multiple outcome
events, and conflicts remain unmeasured. Reapplying the same import is
idempotent; changed fingerprints or duplicate target imports fail validation.
The aggregator independently reruns the local extractor and overlays only an
import whose full detail exactly matches that source-derived result. Missing
sessions, forged aggregates, or stale target fingerprints therefore stay
unmeasured even when the stored event is structurally valid.
