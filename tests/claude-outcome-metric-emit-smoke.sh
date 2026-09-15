#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HOOK="$ROOT_DIR/claude/hooks/outcome-metric-emit.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Ledger with multi_execution usage only
mkdir -p "$TMP/.workflow/run-a"
cat >"$TMP/.workflow/run-a/events.jsonl" <<'JSONL'
{"schema_version":2,"ts":"2026-07-31T12:00:00Z","event":"route_decided","run":"run-a","detail":{"route":"answer","reason":"t"}}
{"schema_version":2,"ts":"2026-07-31T12:00:01Z","event":"multi_execution_completed","run":"run-a","detail":{"participants":[{"id":"agent-scout","model":"opencode-go/deepseek-v4-flash","family":"opencode-go"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":10,"output_tokens":5,"total_tokens":15,"elapsed_ms":10},"fallback_status":"none"}}
JSONL

# Transcript with Claude-style usage
cat >"$TMP/transcript.jsonl" <<'JSONL'
{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":20,"output_tokens":10,"total_tokens":30}}}
JSONL

printf '%s' "{\"cwd\":\"$TMP\",\"transcript_path\":\"$TMP/transcript.jsonl\"}" | node "$HOOK"
# Should have measured outcome with parent+sidecar = 45
jq -e 'select(.event=="outcome_metric" and .detail.measured==true and .detail.total_tokens==45 and .detail.success_kind!="task_grader")' \
	"$TMP/.workflow/run-a/events.jsonl" >/dev/null

# Dedupe on second Stop
printf '%s' "{\"cwd\":\"$TMP\",\"transcript_path\":\"$TMP/transcript.jsonl\"}" | node "$HOOK"
count="$(jq -s '[.[]|select(.event=="outcome_metric")]|length' "$TMP/.workflow/run-a/events.jsonl")"
[ "$count" -eq 1 ]

TMP2="$(mktemp -d)"
trap 'rm -rf "$TMP" "$TMP2"' EXIT
mkdir -p "$TMP2/.workflow/run-cache"
printf '%s\n' '{"schema_version":2,"ts":"2026-07-31T12:00:00Z","event":"route_decided","run":"run-cache","detail":{"route":"answer","reason":"t"}}' \
	>"$TMP2/.workflow/run-cache/events.jsonl"
cat >"$TMP2/transcript-cache.jsonl" <<'JSONL'
{"type":"assistant","message":{"role":"assistant","usage":{"input_tokens":20,"output_tokens":10,"cache_read_input_tokens":500,"cache_creation_input_tokens":40,"total_tokens":30}}}
JSONL
printf '%s' "{\"cwd\":\"$TMP2\",\"transcript_path\":\"$TMP2/transcript-cache.jsonl\"}" | node "$HOOK"
jq -e 'select(.event=="outcome_metric" and .detail.measured==true
	and .detail.usage_schema_version==2
	and .detail.total_tokens==30
	and .detail.cache_read_tokens==500
	and .detail.cache_creation_tokens==40
	and .detail.processed_total_tokens==570)' \
	"$TMP2/.workflow/run-cache/events.jsonl" >/dev/null

# settings fragment references the hook
grep -Fq 'outcome-metric-emit.mjs' "$ROOT_DIR/claude/settings.workflow-hooks.json"

printf 'claude-outcome-metric-emit smoke test: ok\n'
