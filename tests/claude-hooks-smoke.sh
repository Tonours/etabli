#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
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

fixture_input() {
  local fixture="$1"
  sed "s#__CWD__#$TMP_DIR#g" "$ROOT_DIR/tests/fixtures/claude-hooks/$fixture"
}

write_plan() {
  local status="$1"

  cat > "$TMP_DIR/PLAN.md" <<EOF
# PLAN.md

## Meta
- Subject: hook test
- Status: $status
- Last revised: 2026-06-14
- Archive: pending until implemented and validated

## Goal

## Workflow Contract
- Route: implement
- Role: implementer
- Stop condition: validated archive written and root PLAN.md deleted
- Required evidence: smoke test
EOF
}

router_output="$(fixture_input router-review.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" '"hookEventName":"UserPromptSubmit"'
assert_contains "$router_output" 'Route: review'
assert_contains "$router_output" 'Command: /review'
assert_not_contains "$router_output" 'Route: plan-implement'

router_output="$(fixture_input router-architecture-review.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: review'
assert_contains "$router_output" 'Command: /review'
assert_not_contains "$router_output" 'Route: plan-loop'

router_output="$(fixture_input router-roadmap-summary.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: answer'
assert_contains "$router_output" 'read-only, question, or summary request'
assert_not_contains "$router_output" 'Route: plan-loop'

router_output="$(fixture_input router-spec-read.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: answer'
assert_contains "$router_output" 'read-only, question, or summary request'
assert_not_contains "$router_output" 'Route: spec-guide'

router_output="$(fixture_input router-ready-implement.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: implement'
assert_contains "$router_output" 'validated archive written and root PLAN.md deleted'

router_output="$(fixture_input router-linear-ticket.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: linear-ticket-create'
assert_contains "$router_output" 'Command: /linear-ticket-create'
assert_not_contains "$router_output" 'Route: linear-work'

router_output="$(fixture_input router-linear-ticket-infinitive.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: linear-ticket-create'
assert_contains "$router_output" 'Command: /linear-ticket-create'
assert_not_contains "$router_output" 'Route: plan-loop'

router_output="$(fixture_input router-linear-read.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: answer'
assert_not_contains "$router_output" 'Command: /linear-ticket-create'

router_output="$(fixture_input router-bug-check.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: bug-check'
assert_contains "$router_output" 'Command: /bug-check'
assert_not_contains "$router_output" 'Route: linear-work'

router_output="$(fixture_input router-github-pr-review.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: pr-review'
assert_contains "$router_output" 'Command: /pr-review'
assert_not_contains "$router_output" 'Command: /review'

router_output="$(fixture_input router-pr-qa.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: pr-qa'
assert_contains "$router_output" 'Command: /pr-qa'

router_output="$(fixture_input router-sec-pr.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: sec-pr'
assert_contains "$router_output" 'Command: /sec-pr'

router_output="$(fixture_input router-ci-fix.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: ci-fix'
assert_contains "$router_output" 'Command: /ci-fix'

router_output="$(fixture_input router-ci-fix-push.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: ci-fix'
assert_contains "$router_output" 'Command: /ci-fix'
assert_not_contains "$router_output" 'Route: ops-stop'

router_output="$(fixture_input router-remove.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: ops-stop'
assert_contains "$router_output" 'sensitive or destructive action requested'

router_output="$(fixture_input router-implement-verb.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_not_contains "$router_output" 'Route: answer'

router_output="$(fixture_input router-delete-text.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_not_contains "$router_output" 'Route: ops-stop'

router_output="$(fixture_input router-spec-question.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: answer'
assert_not_contains "$router_output" 'Route: plan-loop'

slash_output="$(fixture_input router-slash-command.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
if [ -n "$slash_output" ]; then
  printf 'slash commands should not receive injected router context; got: %s\n' "$slash_output" >&2
  exit 1
fi

write_plan "DRAFT"
guard_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/file.ts","content":"x"}}\n' "$TMP_DIR" "$TMP_DIR" |
    node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$guard_output" '"permissionDecision":"deny"'
assert_contains "$guard_output" 'PLAN.md is DRAFT'

plan_edit_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s/PLAN.md","old_string":"DRAFT","new_string":"READY"}}\n' "$TMP_DIR" "$TMP_DIR" |
    node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
if [ -n "$plan_edit_output" ]; then
  printf 'editing root PLAN.md should remain allowed while planning; got: %s\n' "$plan_edit_output" >&2
  exit 1
fi

nested_plan_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"%s/subdir/PLAN.md","old_string":"DRAFT","new_string":"READY"}}\n' "$TMP_DIR" "$TMP_DIR" |
    node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$nested_plan_output" '"permissionDecision":"deny"'
assert_contains "$nested_plan_output" 'only the root PLAN.md may be edited'

multi_edit_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"MultiEdit","tool_input":{"file_path":"%s/src/file.ts","edits":[]}}\n' "$TMP_DIR" "$TMP_DIR" |
    node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$multi_edit_output" '"permissionDecision":"deny"'
assert_contains "$multi_edit_output" 'PLAN.md is DRAFT'

bash_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf dist"}}\n' "$TMP_DIR" |
    node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$bash_output" '"permissionDecision":"deny"'
assert_contains "$bash_output" 'mutating Bash commands are blocked'

write_plan "READY"
ready_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/file.ts","content":"x"}}\n' "$TMP_DIR" "$TMP_DIR" |
    node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
if [ -n "$ready_output" ]; then
  printf 'READY plans should allow implementation writes; got: %s\n' "$ready_output" >&2
  exit 1
fi

printf 'claude hooks smoke test: ok\n'
