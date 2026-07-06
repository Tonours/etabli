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
  documented_source_surfaces \
  documented_source_surface_files \
  source_of_truth_conflicts; do
  printf '%s\n' "$json_output" | jq -e --arg key "$key" 'has($key)' >/dev/null
done

printf '%s\n' "$json_output" | jq -e '.instruction_budget.baseline_tokens == 9455' >/dev/null
printf '%s\n' "$json_output" | jq -e '.instruction_budget.current_tokens <= .instruction_budget.target_tokens' >/dev/null
printf '%s\n' "$json_output" | jq -e '.instruction_budget.within_target == true' >/dev/null
printf '%s\n' "$json_output" | jq -e '.instruction_budget.current_tokens <= .instruction_budget.stretch_target_tokens' >/dev/null
printf '%s\n' "$json_output" | jq -e '.instruction_budget.within_stretch_target == true' >/dev/null
printf '%s\n' "$json_output" | jq -e '.instruction_budget.files | length == 7' >/dev/null
printf '%s\n' "$json_output" | jq -e '
  (.instruction_budget.files | map(.path) | sort) == [
    "claude/CLAUDE.md",
    "codex/AGENTS.md",
    "pi/AGENTS.md",
    "workflow-scaffold/templates/AGENTS.md",
    "workflow-scaffold/templates/CLAUDE.md",
    "workflow-scaffold/templates/docs/agent-workflow.md",
    "workflow-scaffold/templates/docs/claude-code-workflow.md"
  ]
' >/dev/null
printf '%s\n' "$json_output" | jq -e '.instruction_budget.files[] | select(.path == "codex/AGENTS.md")' >/dev/null

printf '%s\n' "$json_output" | jq -e '.router_adapter_lines[] | select(.path == "claude/hooks/workflow-router-lib.mjs")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.router_adapter_lines[] | select(.path == "pi/extensions/lib/workflow-router-runtime.ts")' >/dev/null
printf '%s\n' "$json_output" | jq -e '.smoke_suites | length > 0' >/dev/null
printf '%s\n' "$json_output" | jq -e '.documented_source_surfaces >= 1' >/dev/null
printf '%s\n' "$json_output" | jq -e '.source_of_truth_conflicts == 0' >/dev/null

assert_contains "$text_output" "shared_contract_files"
assert_contains "$text_output" "router_adapter_lines"
assert_contains "$text_output" "exact_duplicate_pairs"
assert_contains "$text_output" "documented_source_surfaces"
assert_contains "$text_output" "instruction_budget_tokens"
assert_contains "$text_output" "instruction_budget_stretch_ok"

printf 'workflow efficiency report smoke test: ok\n'
