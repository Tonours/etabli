#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"
SESSION_DIR="$TMP_DIR/sessions/2026/07/01"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$SESSION_DIR"

write_run() {
  local run="$1" started_at="$2" ended_at="$3"
  mkdir -p "$EVENT_DIR/$run"
  printf '%s\n' \
    "{\"schema_version\":2,\"ts\":\"$started_at\",\"event\":\"route_decided\",\"run\":\"$run\",\"detail\":{\"route\":\"plan-implement\",\"reason\":\"fixture\"}}" \
    "{\"schema_version\":2,\"ts\":\"$ended_at\",\"event\":\"completed\",\"run\":\"$run\",\"detail\":{\"summary\":\"fixture complete\"}}" \
    > "$EVENT_DIR/$run/events.jsonl"
}

write_run run-a 2026-07-01T00:01:00Z 2026-07-01T00:03:00Z
write_run run-b 2026-07-01T00:04:00Z 2026-07-01T00:06:00Z
write_run run-c 2026-07-01T00:07:00Z 2026-07-01T00:09:00Z
write_run run-d 2026-07-01T00:10:00Z 2026-07-01T00:12:00Z
write_run run-short 2026-07-01T00:12:40Z 2026-07-01T00:13:10Z

cat > "$SESSION_DIR/rollout-2026-07-01T00-00-00-fixture.jsonl" <<'JSONL'
{"timestamp":"2026-07-01T00:00:00.000Z","type":"session_meta","payload":{"id":"secret-session-id","source":"vscode"}}
{"timestamp":"2026-07-01T00:00:10.000Z","type":"event_msg","payload":{"type":"user_message","message":"PRIVATE PROMPT MUST NOT LEAK"}}
{"timestamp":"2026-07-01T00:01:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":20,"total_tokens":120}}}}
{"timestamp":"2026-07-01T00:03:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":150,"output_tokens":30,"total_tokens":180}}}}
{"timestamp":"2026-07-01T00:05:00.000Z","type":"response_item","payload":{"type":"function_call","name":"fixture"}}
{"timestamp":"2026-07-01T00:05:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":260,"output_tokens":50,"total_tokens":310}}}}
{"timestamp":"2026-07-01T00:06:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":300,"output_tokens":60,"total_tokens":360}}}}
{"timestamp":"2026-07-01T00:08:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":410,"output_tokens":80,"total_tokens":490}}}}
{"timestamp":"2026-07-01T00:09:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":450,"output_tokens":90,"total_tokens":540}}}}
{"timestamp":"2026-07-01T00:11:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":560,"output_tokens":110,"total_tokens":670}}}}
{"timestamp":"2026-07-01T00:12:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":600,"output_tokens":120,"total_tokens":720}}}}
{"timestamp":"2026-07-01T00:13:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":620,"output_tokens":125,"total_tokens":745}}}}
JSONL

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append telemetry-import route_decided '{"route":"plan-implement","reason":"telemetry recovery fixture"}'

dry_run="$("$ROOT_DIR/scripts/workflow-telemetry-recover" --workflow-dir "$EVENT_DIR" --sessions-dir "$TMP_DIR/sessions" --dry-run --json)"
printf '%s\n' "$dry_run" | jq -e '.mode == "dry-run" and .terminal_runs == 5 and .recovered_outcomes == 4 and .usage_measurement_coverage == 0.8' >/dev/null
printf '%s\n' "$dry_run" | jq -e '.candidates[] | select(.target_run == "run-short") | .status == "rejected" and .reason == "run-window-too-short"' >/dev/null
if printf '%s\n' "$dry_run" | grep -Eq 'secret-session-id|PRIVATE PROMPT|sessions/2026'; then
  printf 'telemetry recovery dry-run leaked raw session identity, content, or path\n' >&2
  exit 1
fi

STALE_EVENT_DIR="$TMP_DIR/stale-workflow"
STALE_SESSION_DIR="$TMP_DIR/stale-sessions/2026/07/01"
mkdir -p "$STALE_EVENT_DIR/run-stale" "$STALE_SESSION_DIR"
printf '%s\n' \
  '{"schema_version":2,"ts":"2026-07-01T00:10:00Z","event":"route_decided","run":"run-stale","detail":{"route":"plan-implement","reason":"fixture"}}' \
  '{"schema_version":2,"ts":"2026-07-01T00:12:00Z","event":"completed","run":"run-stale","detail":{"summary":"done"}}' \
  > "$STALE_EVENT_DIR/run-stale/events.jsonl"
cat > "$STALE_SESSION_DIR/rollout-2026-07-01T00-00-00-stale.jsonl" <<'JSONL'
{"timestamp":"2026-07-01T00:00:00.000Z","type":"session_meta","payload":{"id":"stale-session","source":"vscode"}}
{"timestamp":"2026-07-01T00:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":20,"total_tokens":120}}}}
{"timestamp":"2026-07-01T00:11:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":200,"output_tokens":40,"total_tokens":240}}}}
{"timestamp":"2026-07-01T00:12:30.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":250,"output_tokens":50,"total_tokens":300}}}}
JSONL
stale_dry_run="$("$ROOT_DIR/scripts/workflow-telemetry-recover" --workflow-dir "$STALE_EVENT_DIR" --sessions-dir "$TMP_DIR/stale-sessions" --dry-run --json)"
printf '%s\n' "$stale_dry_run" | jq -e '.recovered_outcomes == 0 and (.candidates[0].reason == "stale-pre-run-baseline")' >/dev/null

"$ROOT_DIR/scripts/workflow-telemetry-recover" --workflow-dir "$EVENT_DIR" --sessions-dir "$TMP_DIR/sessions" --ledger-run telemetry-import --apply >/dev/null
"$ROOT_DIR/scripts/workflow-telemetry-recover" --workflow-dir "$EVENT_DIR" --sessions-dir "$TMP_DIR/sessions" --ledger-run telemetry-import --apply >/dev/null

ledger="$EVENT_DIR/telemetry-import/events.jsonl"
[ "$(jq -s '[.[] | select(.event == "outcome_measurement_population")] | length' "$ledger")" -eq 1 ]
[ "$(jq -s '[.[] | select(.event == "outcome_measurement_imported")] | length' "$ledger")" -eq 4 ]
if grep -Eq 'secret-session-id|PRIVATE PROMPT|sessions/2026' "$ledger"; then
  printf 'telemetry recovery leaked raw session identity, content, or path\n' >&2
  exit 1
fi
jq -e 'select(.event == "outcome_measurement_imported") | .detail.session_fingerprint | test("^[a-f0-9]{64}$")' "$ledger" >/dev/null

metrics="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR" --sessions-dir "$TMP_DIR/sessions" --json)"
printf '%s\n' "$metrics" | jq -e '.totals.terminal_runs == 5 and .totals.recovered_outcomes == 4 and .totals.usage_measured_outcomes == 4 and .totals.usage_measurement_coverage == 0.8' >/dev/null
printf '%s\n' "$metrics" | jq -e '.telemetry.population_events == 1 and .telemetry.imported_events == 4 and .telemetry.source_verified_imports == 4 and .telemetry.unverified_imports == 0 and .telemetry.unmatched_imports == 0' >/dev/null
printf '%s\n' "$metrics" | jq -e '.telemetry.populations[0] | .terminal_runs == 5 and .baseline_usage_measured_outcomes == 0 and .recovered_outcomes == 4 and .usage_measurement_coverage == 0.8' >/dev/null
# Productivity ratio is task_grader-only (G7). Recovered historical runs are run_terminal,
# so tokens_per_successful_outcome stays null while recovered usage coverage remains real.
printf '%s\n' "$metrics" | jq -e '.totals.tokens_per_successful_outcome == null' >/dev/null
printf '%s\n' "$metrics" | jq -e '.totals.run_terminal_successful_outcomes == 4 and .totals.task_grader_successful_outcomes == 0' >/dev/null

FORGED_DIR="$TMP_DIR/forged-workflow"
cp -R "$EVENT_DIR" "$FORGED_DIR"
jq -c 'if .event == "outcome_measurement_imported" and .detail.target_run == "run-a" then .detail.input_tokens += 1 | .detail.total_tokens += 1 else . end' "$FORGED_DIR/telemetry-import/events.jsonl" > "$TMP_DIR/forged-events.jsonl"
mv "$TMP_DIR/forged-events.jsonl" "$FORGED_DIR/telemetry-import/events.jsonl"
forged_metrics="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$FORGED_DIR" --sessions-dir "$TMP_DIR/sessions" --json)"
printf '%s\n' "$forged_metrics" | jq -e '.totals.recovered_outcomes == 3 and .telemetry.source_verified_imports == 3 and .telemetry.unverified_imports == 1' >/dev/null

printf '\n' >> "$EVENT_DIR/run-a/events.jsonl"
set +e
integrity_output="$("$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate telemetry-import 2>&1)"
integrity_status="$?"
set -e
if [ "$integrity_status" -ne 1 ] || ! printf '%s\n' "$integrity_output" | grep -Fq 'fingerprint mismatch'; then
  printf 'expected target mutation to invalidate recovered telemetry\n%s\n' "$integrity_output" >&2
  exit 1
fi
stale_metrics="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR" --sessions-dir "$TMP_DIR/sessions" --json)"
printf '%s\n' "$stale_metrics" | jq -e '.totals.recovered_outcomes == 0 and .telemetry.source_verified_imports == 0 and .telemetry.unverified_imports == 4' >/dev/null

printf 'workflow telemetry recovery smoke test: ok\n'
