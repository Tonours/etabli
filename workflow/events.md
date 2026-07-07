# Workflow Events

Long-running Etabli runs may record durable progress in
`.workflow/<slug>/events.jsonl`. The run directory is local and gitignored.

The file is append-only: one JSON object per line, never rewritten. Event
shape:

```json
{"ts":"2026-07-03T12:00:00Z","event":"route_decided","run":"slug","detail":{}}
```

Resume by reading `state.json` for structure and replaying `events.jsonl` for
history. The last `completed` or `blocked` event is terminal evidence; a run
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
| `adversary_completed` | `{verdict, accepted_findings, rejected_findings}` |
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
| `outcome_metric` | `{outcome, success, input_tokens, output_tokens, total_tokens, tool_calls, elapsed_ms}` |
| `retry_classified` | `{failure_class, next_action}` |
| `no_progress` | `{check_or_hypothesis, command, attempts, head_sha, eliminated}` |
| `handoff` | `{branch, sha, done, pending, next_action, do_not_redo}` |
| `human_checkpoint` | `{category, decision, target}` |
| `archive_written` | `{path}` |
| `completed` | `{summary}` |
| `blocked` | `{reason, needed_input}` |

`outcome_metric` fields are optional by design so older ledgers stay valid. Use
`success: true` or an `outcome` such as `success`, `passed`, or `completed` for
successful outcomes; `scripts/workflow-metrics` treats missing token counts as
zero rather than inferring them.
