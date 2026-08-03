#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

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

assert_not_contains() {
  local text="$1"
  local needle="$2"

  case "$text" in
    *"$needle"*)
      printf 'did not expect output to contain: %s\noutput was:\n%s\n' "$needle" "$text" >&2
      exit 1
      ;;
  esac
}

assert_empty() {
  local text="$1"
  local label="$2"

  if [ -n "$text" ]; then
    printf '%s should be empty; got:\n%s\n' "$label" "$text" >&2
    exit 1
  fi
}

write_plan() {
  local cwd="$1"
  local status="$2"
  local upper_status
  upper_status="$(printf '%s' "$status" | tr '[:lower:]' '[:upper:]')"

  cat > "$cwd/PLAN.md" <<EOF
# PLAN.md

## Meta
- Subject: agent scenario smoke
- Status: $upper_status
- Last revised: 2026-07-03
- Archive: pending until implemented and validated

## Goal
EOF
}

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required for agent scenario smoke tests\n' >&2
  exit 1
fi

HAS_BUN=0
if command -v bun >/dev/null 2>&1; then
  HAS_BUN=1
else
  printf 'SKIP pi parity (bun missing)\n'
fi

claude_route_probe() {
  node --input-type=module -e '
const lib = await import(process.argv[1]);
const d = lib.classifyWorkflowRoute(process.argv[2], {
  planStatus: lib.readPlanStatus(process.argv[3]),
});
process.stdout.write(
  [
    `Route: ${d.route}`,
    `Reason: ${d.reason}`,
    `Command: ${d.command || "none"}`,
    `Artifact: ${d.artifact}`,
    `Stop: ${d.stopCondition}`,
    `Evidence: ${d.requiredEvidence}`,
  ].join("\n"),
);
' "$ROOT_DIR/claude/hooks/workflow-router-lib.mjs" "$1" "$2"
}

for scenario_dir in "$ROOT_DIR"/tests/agent-scenarios/*/; do
  name="$(basename "$scenario_dir")"
  input="$scenario_dir/input.json"
  expected="$scenario_dir/expected.json"
  scen_tmp="$(mktemp -d "$TMP_ROOT/${name}.XXXXXX")"

  prompt="$(jq -r '.prompt' "$input")"
  plan_status="$(jq -r '.plan_status' "$input")"
  claude_route="$(jq -r '.claude_route' "$expected")"
  pi_route="$(jq -r '.pi_route' "$expected")"
  write_allowed="$(jq -r '.write_allowed' "$expected")"

  if [ "$plan_status" != "missing" ]; then
    write_plan "$scen_tmp" "$plan_status"
  fi

  router_output="$(claude_route_probe "$prompt" "$scen_tmp")"

  assert_contains "$router_output" "Route: $claude_route"

  while IFS= read -r needle; do
    [ -z "$needle" ] && continue
    assert_contains "$router_output" "$needle"
  done < <(jq -r '.context_contains[]?' "$expected")

  while IFS= read -r needle; do
    [ -z "$needle" ] && continue
    assert_not_contains "$router_output" "$needle"
  done < <(jq -r '.context_not_contains[]?' "$expected")

  if [ "$HAS_BUN" -eq 1 ]; then
    pi_output="$(
      cd "$ROOT_DIR/pi"
      bun -e 'import { classifyWorkflowRoute } from "./extensions/lib/workflow-router-runtime.ts"; console.log(JSON.stringify(classifyWorkflowRoute(process.argv[1] ?? "", JSON.parse(process.argv[2] ?? "{}"))));' -- "$prompt" "{\"planStatus\":\"$plan_status\"}"
    )"
    actual_pi_route="$(printf '%s' "$pi_output" | jq -r '.route')"
    actual_write_allowed="$(printf '%s' "$pi_output" | jq -r '.writeAllowed')"
    if [ "$actual_pi_route" != "$pi_route" ]; then
      printf '%s expected pi route %s, got %s\n' "$name" "$pi_route" "$actual_pi_route" >&2
      exit 1
    fi
    if [ "$actual_write_allowed" != "$write_allowed" ]; then
      printf '%s expected writeAllowed %s, got %s\n' "$name" "$write_allowed" "$actual_write_allowed" >&2
      exit 1
    fi
  fi

  guard_expected="$(jq -r '.guard // "null"' "$expected")"
  if [ "$guard_expected" != "null" ]; then
    guard_probe="$(jq -c '.guard_probe' "$input" | sed "s#__CWD__#$scen_tmp#g")"
    guard_input="$(jq -n --arg cwd "$scen_tmp" --argjson probe "$guard_probe" '{cwd:$cwd,hook_event_name:"PreToolUse",tool_name:$probe.tool_name,tool_input:$probe.tool_input}')"
    guard_output="$(printf '%s\n' "$guard_input" | node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs")"
    case "$guard_expected" in
      deny) assert_contains "$guard_output" '"permissionDecision":"deny"' ;;
      allow) assert_empty "$guard_output" "$name guard output" ;;
      *)
        printf '%s has unsupported guard expectation: %s\n' "$name" "$guard_expected" >&2
        exit 1
        ;;
    esac
  fi

  printf 'PASS: %s\n' "$name"
done
