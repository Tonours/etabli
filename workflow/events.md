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
