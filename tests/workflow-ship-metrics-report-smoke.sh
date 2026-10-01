#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
METRICS="$ROOT_DIR/scripts/workflow-ship-metrics"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'ship-metrics-report-smoke: %s\n' "$1" >&2; exit 1; }
jqe() { jq -e "$1" >/dev/null 2>&1; }

DIR="$TMP/.workflow"
mkdir -p "$TMP/empty-wf" "$DIR/run-x" "$DIR/run-old" "$DIR/ship-metrics" "$DIR/guard-journal"

printf '%s\n' \
  '{"schema_version":2,"ts":"2026-09-29T10:00:00Z","event":"route_decided","run":"run-x","detail":{"route":"implement","reason":"t"}}' \
  '{"schema_version":2,"ts":"2026-09-29T10:05:00Z","event":"correction","run":"run-x","detail":{"harness":"pi","prompt_sha256":"abc","prompt_chars":10}}' \
  '{"schema_version":2,"ts":"2026-09-29T10:06:00Z","event":"blocked","run":"run-x","detail":{"reason":"ci_wait","needed_input":"x"}}' \
  '{"schema_version":2,"ts":"2026-09-29T10:07:00Z","event":"human_checkpoint","run":"run-x","detail":{"category":"notification","decision":"requested","target":"permission_prompt","consent_class":"permission_request"}}' \
  '{"schema_version":2,"ts":"2026-09-29T10:08:00Z","event":"ship_completed","run":"run-x","detail":{"ci_state":"green"}}' \
  >"$DIR/run-x/events.jsonl"

printf '%s\n' \
  '{"schema_version":2,"ts":"2026-08-01T10:00:00Z","event":"blocked","run":"run-old","detail":{"reason":"usage_limit","needed_input":"x"}}' \
  >"$DIR/run-old/events.jsonl"

printf '%s\n' '{"run_slug":"run-x","verdict":"GO","escaped_later":1,"tier":"standard"}' >"$DIR/ship-metrics/run-x.json"
printf '%s\n' '{"run_slug":"run-old","verdict":"GO","escaped_later":2,"tier":"small"}' >"$DIR/ship-metrics/run-old.json"
TZ=UTC touch -t 202609291000 "$DIR/ship-metrics/run-x.json"
TZ=UTC touch -t 202608010000 "$DIR/ship-metrics/run-old.json"

printf '%s\n' \
  '{"ts":"2026-09-29T10:00:00Z","host":"h","harness":"pi","guard":"no-comments","pattern":"code-comment-added","target":"a.ts","tool":"Write"}' \
  '{"ts":"2026-09-29T10:01:00Z","host":"h","harness":"claude","guard":"check-freeze","pattern":"freeze-bash-bypass","target":"PLAN.md","tool":"Bash"}' \
  >"$DIR/guard-journal/2026-09-29.jsonl"

HERDR="$TMP/herdr.jsonl"
printf '%s\n' \
  '{"ts":"2026-09-29T10:00:00Z","host":"h","pane_id":"p1","agent":"claude","status":"working","state_change_seq":1}' \
  '{"ts":"2026-09-29T10:00:30Z","host":"h","pane_id":"p1","agent":"claude","status":"blocked","state_change_seq":2}' \
  '{"ts":"2026-09-29T10:01:30Z","host":"h","pane_id":"p1","agent":"claude","status":"working","state_change_seq":4}' \
  '{"ts":"2026-09-29T10:02:00Z","host":"h","pane_id":"p1","agent":"claude","status":"idle","state_change_seq":5}' \
  >"$HERDR"

out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --until 2026-09-29 --herdr-history "$HERDR" --json)"
printf '%s' "$out" | jqe '.sources.event_ledgers == "available"' || fail "ledgers must be available"
printf '%s' "$out" | jqe '.primaries.corrections == 1' || fail "date-only --until must include the whole day"
printf '%s' "$out" | jqe '.sources.accepted_merge_receipts == "missing"' || fail "accepted merges must stay missing"
printf '%s' "$out" | jqe '.primaries.corrections == 1' || fail "date-only --until must include the whole day"
printf '%s' "$out" | jqe '.primaries.blocked_by_reason == {"ci_wait": 1}' || fail "out-of-window blocked must be excluded"
printf '%s' "$out" | jqe '.primaries.checkpoints_by_consent_class == {"permission_request": 1}' || fail "consent classes expected"
printf '%s' "$out" | jqe '.primaries.ship_completed_by_ci_state == {"green": 1}' || fail "ci_state must come from ledger ship_completed events"
printf '%s' "$out" | jqe '.primaries.guards_by_guard == {"no-comments": 1, "check-freeze": 1}' || fail "guard counts expected"
printf '%s' "$out" | jqe '.counters.escaped_later_total == 1' || fail "out-of-window registry row must be excluded"
printf '%s' "$out" | jqe '.counters.tier_counts == {"standard": 1}' || fail "tier window filter expected"
printf '%s' "$out" | jqe '.counters.herdr.panes == 1' || fail "one herdr pane expected"
printf '%s' "$out" | jqe '.counters.herdr.holes == 1' || fail "the seq 2->4 gap must be one hole"
printf '%s' "$out" | jqe '.counters.herdr.known_seconds == 60' || fail "known time must exclude the hole interval (30s + 30s)"
printf '%s' "$out" | jqe '.outcome.accepted_results == null' || fail "accepted results must be null until receipts"

before_files="$(find "$DIR" -type f | sort | md5)"
text="$("$METRICS" --dir "$DIR" report --since 2026-09-29)"
case "$text" in
  *outcome*) ;;
  *) fail "text output must carry the outcome block" ;;
esac
after_files="$(find "$DIR" -type f | sort | md5)"
[ "$before_files" = "$after_files" ] || fail "report must not write any file"

rm -rf "$DIR/guard-journal"
out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.guard_journal == "missing"' || fail "missing journal must be named"
printf '%s' "$out" | jqe '.primaries.guards_by_guard == null' || fail "guards must be null when the journal is missing"

out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --herdr-history "$TMP" --json)"
printf '%s' "$out" | jqe '.sources.herdr_history == "unreadable"' || fail "unreadable herdr source must be named"

out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.herdr_history == "not-provided"' || fail "absent herdr flag must read not-provided"

if "$METRICS" --dir "$DIR" report --until 2026-09-30 --json >/dev/null 2>&1; then
  fail "report without --since must fail"
fi

mkdir -p "$DIR/run-crash/events.jsonl"
out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.event_ledgers == "partial"' || fail "an unreadable ledger must degrade the source state, not crash"
rm -rf "$DIR/run-crash"

printf '%s\n' '{truncated' >>"$DIR/run-x/events.jsonl"
printf '%s\n' 'null' >"$DIR/ship-metrics/null-row.json"
printf '%s\n' '[]' >>"$DIR/run-x/events.jsonl"
out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.event_ledgers == "partial"' || fail "a corrupted ledger line must read as partial, not a false zero"
printf '%s' "$out" | jqe '.sources.ship_metrics_registry == "partial"' || fail "a null registry row must degrade the registry state, not crash"
rm -f "$DIR/ship-metrics/null-row.json"
printf '%s\n' '{}' >"$DIR/ship-metrics/shapeless-row.json"
out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.ship_metrics_registry == "partial"' || fail "an empty-object registry row must degrade the registry state, not count as available"
rm -f "$DIR/ship-metrics/shapeless-row.json"
mkdir -p "$DIR/guard-journal"
printf '%s\n' '{}' >"$DIR/guard-journal/2026-09-29.jsonl"
out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.guard_journal == "partial"' || fail "an empty-object journal entry must degrade the journal state, not count as a denial"
rm -f "$DIR/guard-journal/2026-09-29.jsonl"
mv "$DIR/run-x/events.jsonl" "$DIR/run-x/events.keep"
printf '%s\n' '{}' >"$DIR/run-x/events.jsonl"
out="$("$METRICS" --dir "$DIR" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.event_ledgers == "partial"' || fail "a ledger of only empty objects must read as partial, not a false zero"
mv "$DIR/run-x/events.keep" "$DIR/run-x/events.jsonl"

virgin="$(mktemp -d)"
out="$("$METRICS" --dir "$virgin/.workflow" report --since 2026-09-29 --json)"
printf '%s' "$out" | jqe '.sources.ship_metrics_registry == "missing"' || fail "a virgin dir must report the registry missing"
[ ! -e "$virgin/.workflow/ship-metrics" ] || fail "report must not create the registry directory it reports missing"
rm -rf "$virgin"

HERDR2="$TMP/herdr2.jsonl"
printf '%s\n' \
  '{"ts":"2026-09-29T09:59:00Z","host":"a","pane_id":"p1","state_change_seq":1}' \
  '{"ts":"2026-09-29T11:01:00Z","host":"a","pane_id":"p1","state_change_seq":2}' \
  >"$HERDR2"
out="$("$METRICS" --dir "$TMP/empty-wf" report --since 2026-09-29T10:00:00Z --until 2026-09-29T11:00:00Z --herdr-history "$HERDR2" --json)"
printf '%s' "$out" | jqe '.counters.herdr.known_seconds == 3600' || fail "an interval enclosing the window must contribute the clipped 3600s"

HERDR3="$TMP/herdr3.jsonl"
printf '%s\n' \
  '{"ts":"2026-09-29T10:00:00Z","host":"a","pane_id":"p1","state_change_seq":1}' \
  '{"ts":"2026-09-29T10:01:00Z","host":"b","pane_id":"p1","state_change_seq":2}' \
  >"$HERDR3"
out="$("$METRICS" --dir "$TMP/empty-wf" report --since 2026-09-29 --herdr-history "$HERDR3" --json)"
printf '%s' "$out" | jqe '.counters.herdr.known_seconds == 0' || fail "no interval may be fabricated across hosts"
printf '%s' "$out" | jqe '.counters.herdr.panes == 2' || fail "same pane on two hosts must count as two panes"

bash "$ROOT_DIR/tests/guard-journal-isolation-smoke.sh"
printf 'ship-metrics-report-smoke: PASS\n'
