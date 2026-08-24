#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
BENCH_DIR="$(mktemp -d)"
trap 'rm -rf "$BENCH_DIR"' EXIT
WORKFLOW="$BENCH_DIR/.workflow"

# correctness fast-path: script must parse
bash -n "$ROOT/scripts/workflow-event"

REPS=15
TIMES_FILE="$(mktemp)"
trap 'rm -rf "$BENCH_DIR" "$TIMES_FILE"' EXIT
for i in $(seq 1 "$REPS"); do
  run="bench-run-$i"
  start_ns=$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')
  "$ROOT/scripts/workflow-event" --dir "$WORKFLOW" append "$run" route_decided '{"route":"plan-loop","reason":"bench"}' >/dev/null 2>&1
  end_ns=$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')
  echo $(( (end_ns - start_ns) / 1000000 )) >>"$TIMES_FILE"
done

sort -n "$TIMES_FILE" >/dev/null
MEDIAN=$(sort -n "$TIMES_FILE" | awk '{a[NR]=$1} END {print (NR%2==1) ? a[(NR+1)/2] : int((a[NR/2]+a[NR/2+1])/2)}')

start_ns=$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')
"$ROOT/scripts/workflow-event" --dir "$WORKFLOW" validate bench-run-1 >/dev/null 2>&1
end_ns=$(date +%s%N 2>/dev/null || python3 -c 'import time;print(int(time.time()*1e9))')
VALIDATE_MS=$(( (end_ns - start_ns) / 1000000 ))

COUNT=$(wc -l <"$WORKFLOW/bench-run-1/events.jsonl" | tr -d ' ')
echo "METRIC append_ms=$MEDIAN"
echo "METRIC validate_ms=$VALIDATE_MS"
echo "METRIC append_count=$COUNT"
