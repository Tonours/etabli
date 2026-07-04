#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/workflow-efficiency-report"

assert_contains() {
  local text="$1"
  local needle="$2"

  case "$text" in
    *"$needle"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$needle" "$text" >&2
      exit 1
      ;;
  esac
}

before_status="$(git -C "$ROOT_DIR" status --porcelain)"
text_output="$("$SCRIPT")"
json_output="$("$SCRIPT" --json)"
after_status="$(git -C "$ROOT_DIR" status --porcelain)"

if [ "$before_status" != "$after_status" ]; then
  printf 'workflow-efficiency-report mutated git status\nbefore:\n%s\nafter:\n%s\n' "$before_status" "$after_status" >&2
  exit 1
fi

printf '%s\n' "$json_output" | jq empty

for key in \
  shared_contract_files \
  shared_contract_lines \
  adapter_files \
  adapter_total_lines \
  router_adapter_lines \
  exact_duplicate_pairs \
  instruction_dup_sections \
  smoke_suites \
  smoke_total_lines \
  source_of_truth_conflicts; do
  printf '%s\n' "$json_output" | jq -e --arg key "$key" 'has($key)' >/dev/null
done

printf '%s\n' "$json_output" | jq -e '.router_adapter_lines[] | select(.path == "claude/hooks/workflow-router-lib.mjs")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.router_adapter_lines[] | select(.path == "pi/extensions/lib/workflow-router-runtime.ts")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.smoke_suites | length > 0' >/dev/null

assert_contains "$text_output" "shared_contract_files"
assert_contains "$text_output" "router_adapter_lines"
assert_contains "$text_output" "exact_duplicate_pairs"

printf 'workflow efficiency report smoke test: ok\n'
