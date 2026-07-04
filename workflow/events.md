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

## Event Types

| Type | Detail convention |
| --- | --- |
| `route_decided` | `{route, reason}` |
| `plan_created` | `{path, status}` |
| `adversary_completed` | `{verdict, accepted_findings, rejected_findings}` |
| `file_changed` | `{path, change}` |
| `validation_run` | `{command, exit}` |
| `validation_failed` | `{command, exit, failure}` |
| `retry_classified` | `{failure_class, next_action}` |
| `human_checkpoint` | `{category, decision, target}` |
| `archive_written` | `{path}` |
| `completed` | `{summary}` |
| `blocked` | `{reason, needed_input}` |
