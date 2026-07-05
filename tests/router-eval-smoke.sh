#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/router-eval"

if ! command -v bun >/dev/null 2>&1; then
  printf 'router eval smoke test: skipped (bun missing)\n'
  exit 0
fi

json_output="$("$SCRIPT" --json --min-accuracy 1 --require-alignment)"
text_output="$("$SCRIPT" --min-accuracy 1 --require-alignment)"

printf '%s\n' "$json_output" | jq -e '.total >= 10' >/dev/null
printf '%s\n' "$json_output" | jq -e '.accuracy == 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.alignmentRate == 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.writeRouteFalsePositives == 0' >/dev/null
printf '%s\n' "$json_output" | jq -e '.opsStopMisses == 0' >/dev/null
printf '%s\n' "$json_output" | jq -e '.researchRouteMisses == 0' >/dev/null

case "$text_output" in
  *accuracy=1*alignment_rate=1*) ;;
  *)
    printf 'expected text metrics in router eval output\n%s\n' "$text_output" >&2
    exit 1
    ;;
esac

printf 'router eval smoke test: ok\n'
