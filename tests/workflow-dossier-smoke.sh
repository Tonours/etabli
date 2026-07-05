#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a route_decided '{"route":"plan-implement","reason":"test"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a validation_failed '{"command":"POSTMARK_TOKEN=secret npm test","exit":1,"failure":"password leaked in failure context"}'
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append run-a blocked '{"reason":"needs input","needed_input":"pick fix path"}'

dossier="$("$ROOT_DIR/scripts/workflow-dossier" --dir "$EVENT_DIR" run-a)"
printf '%s\n' "$dossier" | jq -e '.run == "run-a"' >/dev/null
printf '%s\n' "$dossier" | jq -e '.terminal_event == "blocked"' >/dev/null
printf '%s\n' "$dossier" | jq -e '.route == "plan-implement"' >/dev/null
printf '%s\n' "$dossier" | jq -e '.recommended_next_action == "pick fix path"' >/dev/null

if printf '%s\n' "$dossier" | grep -Eiq 'POSTMARK_TOKEN|secret|password leaked'; then
  printf 'dossier leaked sensitive command or failure content\n' >&2
  exit 1
fi

printf 'workflow dossier smoke test: ok\n'
