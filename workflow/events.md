# Workflow Events

Long-running Etabli runs may record durable progress in
`.workflow/<slug>/events.jsonl`. The run directory is local and gitignored.

The file is append-only: one JSON object per line, never rewritten. Event
shape:

```json
{"schema_version":1,"ts":"2026-07-03T12:00:00Z","event":"route_decided","run":"slug","detail":{"route":"plan-loop","reason":"broad task"}}
```

Resume by replaying `events.jsonl`; derived summaries are disposable, not a
second source of truth. The last `completed` or `blocked` event is terminal evidence; a run
with neither is in progress.

Write events with `scripts/workflow-event append <slug> <type> [json-detail]`.
When that script is unavailable in a scaffolded project, an equivalent single
validated append is acceptable. Do not edit earlier lines.

Read ledgers with `scripts/workflow-monitor`, aggregate optional token/outcome
metrics with `scripts/workflow-metrics`, create sanitized replay/debug dossiers
with `scripts/workflow-dossier`, and mine recurring workflow issues with
`scripts/workflow-retrospect`.

## Event Types

| Type | Detail convention |
| --- | --- |
| `route_decided` | `{route, reason}` |
| `plan_created` | `{path, status}` |
| `adversary_completed` | `{mode: plan|code_diff, verdict, accepted_findings, rejected_findings}` |
| `review_completed` | `{status, evidence}` |
| `simplification_completed` | `{status, evidence}` |
| `file_changed` | `{path, change}` |
| `validation_run` | `{command, exit}` |
| `validation_failed` | `{command, exit, failure}` |
| `dogfood_matrix_created` | `{path, flows, scenarios}` |
| `dogfood_scenario_run` | `{scenario, surface, status, artifacts}` |
| `dogfood_fix_applied` | `{scenario, fix, evidence}` |
| `dogfood_blocked` | `{scenario, reason, needed_input}` |
| `self_improvement_candidate` | `{source, category, outcome, confidence, evidence, held_in?, held_out?}` |
| `harness_failure_pattern` | `{terminal_cause, causal_status, mechanism, verifier, traces}` |
| `harness_proposal` | `{candidate, editable_surfaces, preserve, held_in, held_out}` |
| `harness_candidate_rejected` | `{candidate, reason, regressions, evidence}` |
| `project_slice_planned` | `{slice, owner, validation, dependencies}` |
| `project_slice_completed` | `{slice, validation, evidence, remaining}` |
| `runtime_run_attached` | `{adapter:"pi-workflow", run_id, workflow, state_path:".pi/workflows/<run-id>", status, usage_measured}` |
| `multi_execution_completed` | `{participants:[{id,model,family}], independent_first_passes, disagreement, adjudicator, verdict:accepted|degraded|blocked|rollback_to_opt_in, usage:{measured,...}, fallback_status:none|degraded|blocked}` |
| `outcome_metric` | `{outcome, success, input_tokens, output_tokens, total_tokens, tool_calls, elapsed_ms}` |
| `retry_classified` | `{failure_class, next_action}` |
| `no_progress` | `{check_or_hypothesis, command, attempts, head_sha, eliminated}` |
| `handoff` | `{branch, sha, done, pending, next_action, do_not_redo}` |
| `human_checkpoint` | `{category, decision, target}` |
| `archive_written` | `{path}` |
| `plan_removed` | `{path:"PLAN.md"}` |
| `completed` | `{summary}` |
| `blocked` | `{reason, needed_input}` |

New autonomous ledgers use `validate --profile autonomous-completed`; missing
ledgers fail unless explicit `--allow-missing` legacy compatibility is selected.
Unavailable telemetry is recorded with `measured:false`, never as zero. Use
`success: true` or an `outcome` such as `success`, `passed`, or `completed` for
successful outcomes; historical ledgers remain readable as `legacy_unmeasured`.

`runtime_run_attached` links adapter-owned evidence to the Etabli run; it does
not make `.pi/workflows/<run-id>/` a second planning or progress source of
truth. Its `state_path` must be exactly `.pi/workflows/<run_id>`, its status must
match a pi-workflow run status, and unavailable usage is represented by
`usage_measured:false` rather than zero-valued token fields.

`multi_execution_completed` accepts only the tracked portfolio model IDs and
their matching `openai`, `zai`, or `kimi` family. When `usage.measured` is true,
non-negative `input_tokens`, `output_tokens`, `total_tokens`, and `elapsed_ms`
are required; `total_tokens` cannot be lower than input plus output.

Historical events without `protocol_version` remain valid. Protocol v2 adds
`trigger`, `strategy`, deduplicated bounded `signals`, `rounds`, `claim_count`,
`disagreement_count`, `stop_reason`, numeric requested `budget`, and measured or
explicitly unmeasured `stage_usage` for first pass, rebuttal, and adjudication.
Adaptive v2 evidence needs at least one signal. Scouts cannot rebut or judge;
an adjudication round requires `etabli-sol-judge`. If claims or any measured
stage/total output exceed the requested budget, only `stop_reason: budget_cap`
with a `degraded` or `blocked` verdict validates; an accepted overage is
rejected. V2 budgets are canonical rather than caller-selected: scout uses
`600/0/0/600` and council uses `1800/700/650/3500` for
first-pass/rebuttal/adjudication/total output, both with six claims. The
validator also binds adaptive signals to the selected strategy, keeps Sol out
of participants, requires unique participant IDs and models, and validates the
portfolio shape: one Luna/Terra scout, or Luna/Terra plus GLM for a normal
council, with Kimi admitted only as the explicit replacement. It also rejects
contradictions between disagreement counts, fallback, verdict, stop reason,
and executed rounds. `fallback_status` carries replacement degradation, so a
degraded fallback run keeps its real resolution reason such as `agreement`,
`rebuttal_resolved`, or `adjudicated` instead of overwriting it with
`stop_reason: degraded`.
