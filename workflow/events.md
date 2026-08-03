# Workflow Events

Long-running Etabli runs may record durable progress in
`.workflow/<slug>/events.jsonl`. The run directory is local and gitignored.

The file is append-only: one JSON object per line, never rewritten. Event
shape:

```json
{"schema_version":2,"ts":"2026-07-03T12:00:00Z","event":"route_decided","run":"slug","detail":{"route":"plan-loop","reason":"broad task"}}
```

Resume by replaying `events.jsonl`; derived summaries are disposable, not a
second source of truth. A schema-v2 `completed` or `blocked` event must be the
final event; a valid run with neither is in progress. Legacy ledgers remain
readable but are not authoritative for new strict profiles.

Write events with `scripts/workflow-event append <slug> <type> [json-detail]`.
Before a run relies on runtime receipts or mutation/no-progress authority, select
it with `scripts/workflow-event activate <slug>`; the runtime then inspects only
that ledger. Without a pointer, the compatibility fallback considers only valid
non-terminal ledgers; an invalid historical record that already contains a
terminal event is not an active run, while an invalid non-terminal candidate
still fails closed. Terminal append clears the matching pointer.
If a ledger is corrupt, use `scripts/workflow-event recover <slug> <reason-code>`:
it preserves the original as `events.invalid-*.jsonl` and writes a blocked
replacement instead of deleting history. When that script is unavailable in a
scaffolded project, an equivalent single validated append is acceptable. Do not
edit earlier lines.

Mine recurring workflow issues with
`scripts/workflow-retrospect`. `scripts/workflow-telemetry-recover` is dormant
historical tooling for recovering usage from pre-recenter Codex session logs;
only explicit `--apply` writes the pinned population and imports to the active
ledger.

## Event Types

| Type | Detail convention |
| --- | --- |
| `route_decided` | `{route, reason}` |
| `plan_created` | `{path, status}` |
| `adversary_completed` | `{mode: plan | code_diff, verdict, accepted_findings, rejected_findings}` |
| `review_completed` | `{status, evidence}` |
| `simplification_completed` | `{status, evidence}` |
| `file_changed` | `{path, change}` |
| `validation_run` | `{command, exit}` |
| `validation_failed` | `{command, exit, failure}` |
| `dogfood_matrix_created` | `{path, flows, scenarios}` |
| `dogfood_scenario_run` | `{scenario, surface, status, artifacts}` |
| `dogfood_fix_applied` | `{scenario, fix, evidence}` |
| `dogfood_blocked` | `{scenario, reason, needed_input}` |
| `self_improvement_candidate` | `{source, category, outcome, confidence, evidence, held_in?, held_out?, supersedes?}` |
| `harness_failure_pattern` | `{terminal_cause, causal_status, mechanism, verifier, traces}` |
| `harness_proposal` | `{candidate, editable_surfaces, preserve, held_in, held_out, supersedes?}` — a proposal whose `candidate` matches a prior `harness_candidate_rejected.candidate` must list it in `supersedes`; enforced by `scripts/workflow-supersession-check` |
| `harness_validation_completed` | `{candidate, verdict:accepted | rejected, reason, held_in:{baseline:{population,passed,total},candidate:{population,passed,total}}, held_out:{...}, checks, evidence}` |
| `harness_candidate_rejected` | `{candidate, reason, regressions, evidence}` |
| `project_slice_planned` | `{slice, owner, validation, dependencies}` |
| `project_slice_completed` | `{slice, validation, evidence, remaining}` |
| `runtime_run_attached` | `{adapter:"pi-workflow", run_id, workflow, state_path:".pi/workflows/<run-id>", status, usage_measured}` |
| `runtime_receipt` | `{receipt_for, source, kind:file_change\|validation\|review\|archive\|completion, subject_sha256, exit?, worktree_sha256?, artifact_sha256?, observed_by:"parent-process", cryptographic:false}` — non-cryptographic parent-process observation binding a ledger assertion to a hashed subject (path or command) and exit; stores only allowlisted hashes, never raw output or secret-bearing text |
| `multi_execution_completed` | `{participants:[{id,model,family}], independent_first_passes, disagreement, adjudicator, verdict:accepted | degraded | blocked | rollback_to_opt_in, usage:{measured,...}, fallback_status:none | degraded | blocked}` |
| `outcome_measurement_population` | `{population_id, manifest_sha256, terminal_runs, targets:[{target_run, target_ledger_sha256, target_terminal, target_terminal_event_sha256, target_outcome_event_sha256, baseline_measured, baseline_usage_measured}]}` |
| `outcome_measurement_imported` | `{population_id, import_id, target_run, target fingerprints, source_adapter:"codex", source_scope:"primary_session_window", selection:"shortest_enclosing_primary_session", session_fingerprint, window/sample bounds, sample_count, success, input_tokens, output_tokens, total_tokens, tool_calls, elapsed_ms}` |
| `outcome_metric` | measured: `{outcome, success, measured:true, input_tokens, output_tokens, total_tokens, tool_calls, elapsed_ms}`; unavailable: `{outcome, success, measured:false, reason}`. Additive optional runtime fields in either branch (validated when present, ignored when absent): `runtime` (provider/runtime id string), `turn_count`, `auto_continue_count`, `token_estimate`, `wall_clock_ms`, `success_kind` (`run_terminal`\|`task_grader`), `grader_success`, `participant_usage` (`[{id,role?,input_tokens,output_tokens,total_tokens}]` whose totals must sum to `total_tokens` when measured), `batch_wall_clock_ms`, `batch_started_at`, `batch_terminal_at` (ISO-8601 Z). Prefer `total_tokens` = all model participants; prefer `batch_wall_clock_ms` = batch makespan for verified throughput. Producers: Pi `agent_settled` via `scripts/lib/outcome-metric-emit.mjs`, CLI `scripts/workflow-outcome-metric` |
| `retry_classified` | `{failure_class, next_action}` |
| `no_progress` | `{check_or_hypothesis, command, attempts, head_sha, eliminated}` |
| `handoff` | `{branch, sha, done, pending, next_action, do_not_redo}` |
| `human_checkpoint` | `{category, decision, target}` |
| `archive_written` | `{path}` |
| `plan_removed` | `{path:"PLAN.md"}` |
| `completed` | `{summary}` |
| `blocked` | `{reason, needed_input}` |

New events use envelope `schema_version:2`, whose detail contracts are explicit
and enforced by `scripts/lib/workflow-event-detail.jq`. Version 1 and legacy
envelopes remain readable through named detail shapes and a bounded
post-terminal compatibility path. Any v2 terminal or following event keeps
strict terminal ordering, and newly appended events cannot use the weaker
historical shapes.

New autonomous ledgers use `validate --profile autonomous-completed`; missing
ledgers fail unless explicit `--allow-missing` legacy compatibility is selected.
Unavailable telemetry is recorded with `measured:false` and a non-empty
`reason`, never as zero. Measured events require non-negative integer token and
tool counts, elapsed time, and a total at least as large as input plus output. Use
`success: true` or an `outcome` such as `success`, `passed`, or `completed` for
successful outcomes; historical ledgers remain readable as `legacy_unmeasured`.

`runtime_run_attached` links adapter-owned evidence to the Etabli run; it does
not make `.pi/workflows/<run-id>/` a second planning or progress source of
truth. Its `state_path` must be exactly `.pi/workflows/<run_id>`, its status must
match a pi-workflow run status, and unavailable usage is represented by
`usage_measured:false` rather than zero-valued token fields.

`harness_validation_completed` is only for a real comparative run over the
same baseline/candidate population in each held-in and held-out split. Counts
are non-negative integers, totals are positive and match within each split,
`passed` cannot exceed `total`, and each result names the same non-empty stable
population identifier as its baseline/candidate peer. An `accepted` verdict
requires a strict held-in gain and held-out non-regression. Comparative
negative results use `rejected`; candidates rejected before a comparable run
keep using `harness_candidate_rejected`. Metrics report per-candidate
percentage-point deltas and never average heterogeneous suites into a global
improvement score.

`multi_execution_completed` requires a non-empty model ID whose prefix matches
its declared family. When `usage.measured` is true,
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

Historical usage recovery is an evidence overlay, not a rewrite. A single
`outcome_measurement_population` pins the exact terminal-run manifest and its
content fingerprints. Each `outcome_measurement_imported` must be a unique
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

Runtime usage from `multi_execution_completed` is reported independently and
never counts as a successful outcome without an `outcome_metric`.

`workflow-retrospect` confirms recurrence from independent ledger initiatives,
not raw occurrences. A terminal `-vN`, `-retryN`, `-attemptN`, or `-rerunN`
suffix is treated as another execution of the same initiative. Plan archives
remain visible as supporting evidence; when ledger evidence exists for a
finding, an archive cannot increase its recurrence count.
