#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a outcome_metric '{"outcome":"success","input_tokens":100,"output_tokens":50,"tool_calls":3,"elapsed_ms":1200}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a outcome_metric '{"outcome":"failed","input_tokens":200,"output_tokens":25,"tool_calls":1,"elapsed_ms":800}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-b outcome_metric '{"success":true,"total_tokens":300,"tool_calls":2,"elapsed_ms":1000}'

json_output="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR" --json)"
text_output="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR")"

printf '%s\n' "$json_output" | jq -e '.totals.outcomes == 3' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.successful_outcomes == 2' >/dev/null
printf '%s\n' "$json_output" | jq -e '.totals.tokens_per_successful_outcome == 225' >/dev/null

case "$text_output" in
  *tokens_per_successful_outcome=225*) ;;
  *)
    printf 'expected token metric in text output\n%s\n' "$text_output" >&2
    exit 1
    ;;
esac

printf 'workflow metrics smoke test: ok\n'
