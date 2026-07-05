#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$EVENT_DIR/stale-run" "$EVENT_DIR/blocked-run" "$EVENT_DIR/failing-run"
cat >"$EVENT_DIR/stale-run/events.jsonl" <<'JSONL'
{"ts":"2020-01-01T00:00:00Z","event":"route_decided","run":"stale-run","detail":{"route":"plan-implement"}}
JSONL
cat >"$EVENT_DIR/blocked-run/events.jsonl" <<'JSONL'
{"ts":"2026-01-01T00:00:00Z","event":"route_decided","run":"blocked-run","detail":{"route":"plan-implement"}}
{"ts":"2026-01-01T00:01:00Z","event":"blocked","run":"blocked-run","detail":{"reason":"missing input","needed_input":"user decision"}}
JSONL
cat >"$EVENT_DIR/failing-run/events.jsonl" <<'JSONL'
{"ts":"2099-01-01T00:00:00Z","event":"route_decided","run":"failing-run","detail":{"route":"plan-implement"}}
{"ts":"2099-01-01T00:01:00Z","event":"validation_failed","run":"failing-run","detail":{"command":"test","exit":1,"failure":"red"}}
JSONL

before_status="$(git -C "$ROOT_DIR" status --porcelain)"
json_output="$("$ROOT_DIR/scripts/workflow-monitor" --dir "$EVENT_DIR" --stale-minutes 1 --json)"
text_output="$("$ROOT_DIR/scripts/workflow-monitor" --dir "$EVENT_DIR" --stale-minutes 1)"
after_status="$(git -C "$ROOT_DIR" status --porcelain)"

if [ "$before_status" != "$after_status" ]; then
  printf 'workflow-monitor mutated git status\n' >&2
  exit 1
fi

printf '%s\n' "$json_output" | jq -e '.[] | select(.run == "stale-run" and .status == "stale")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.[] | select(.run == "blocked-run" and .status == "blocked")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.[] | select(.run == "failing-run" and .status == "failing")' >/dev/null

case "$text_output" in
  *stale-run*blocked-run*failing-run*|*blocked-run*failing-run*stale-run*|*failing-run*stale-run*blocked-run*) ;;
  *)
    printf 'expected text output to mention all runs\n%s\n' "$text_output" >&2
    exit 1
    ;;
esac

printf 'workflow monitor smoke test: ok\n'
