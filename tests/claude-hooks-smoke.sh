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

assert_empty() {
  local text="$1"
  local label="$2"

  if [ -n "$text" ]; then
    printf '%s should not receive injected router context; got: %s\n' "$label" "$text" >&2
    exit 1
  fi
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
assert_empty "$router_output" "roadmap summary"

router_output="$(fixture_input router-spec-read.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_empty "$router_output" "spec read"

write_plan "READY"
router_output="$(fixture_input router-ready-implement.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: implement'
assert_contains "$router_output" 'validated archive written and root PLAN.md deleted'
rm -f "$TMP_DIR/PLAN.md"

router_output="$(fixture_input router-ready-implement.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_contains "$router_output" 'actual PLAN.md status is not proven READY'
assert_not_contains "$router_output" 'Route: implement'

write_plan "READY"
router_output="$(fixture_input router-ready-read-only.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_empty "$router_output" "ready read-only"
rm -f "$TMP_DIR/PLAN.md"

router_output="$(fixture_input router-linear-ticket.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: linear-ticket-create'
assert_contains "$router_output" 'Command: /linear-ticket-create'
assert_not_contains "$router_output" 'Route: linear-work'

router_output="$(fixture_input router-linear-ticket-infinitive.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: linear-ticket-create'
assert_contains "$router_output" 'Command: /linear-ticket-create'
assert_not_contains "$router_output" 'Route: plan-loop'

router_output="$(fixture_input router-linear-read.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_empty "$router_output" "linear read"

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

router_output="$(fixture_input router-question-implement.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_not_contains "$router_output" 'Route: answer'

router_output="$(fixture_input router-read-then-fix.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_not_contains "$router_output" 'Route: answer'

router_output="$(fixture_input router-ambient-implementation.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_not_contains "$router_output" 'Route: answer'

router_output="$(fixture_input router-autonomous-plan-loop.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_contains "$router_output" 'autonomous plan-loop request'
assert_contains "$router_output" 'Plan chain: planning -> plan-loop'
assert_contains "$router_output" 'Autonomous completion evidence:'
assert_contains "$router_output" 'Runtime loop: use Claude Code `/goal`'
assert_contains "$router_output" 'workflow/runtime-capabilities.json'
assert_not_contains "$router_output" 'TaskCreate'
assert_not_contains "$router_output" 'TaskList'
assert_not_contains "$router_output" 'Route: plan-loop'

router_output="$(fixture_input router-adversary.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: adversary'
assert_contains "$router_output" 'Command: /adversary'
assert_not_contains "$router_output" 'Route: review'

router_output="$(fixture_input router-adversarial-code-review.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: review'
assert_not_contains "$router_output" 'Route: adversary'

router_output="$(fixture_input router-read-only-adversary.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: review'
assert_contains "$router_output" 'read-only adversarial review request'
assert_not_contains "$router_output" 'Route: adversary'

router_output="$(fixture_input router-delete-text.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_contains "$router_output" 'Route: plan-implement'
assert_not_contains "$router_output" 'Route: ops-stop'

router_output="$(fixture_input router-spec-question.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_empty "$router_output" "spec question"

slash_output="$(fixture_input router-slash-command.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_empty "$slash_output" "slash commands"

slash_goal_output="$(fixture_input router-goal-command.json | node "$ROOT_DIR/claude/hooks/workflow-router.mjs")"
assert_empty "$slash_goal_output" "Claude /goal commands"

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

guard_repo="$TMP_DIR/plan-commit-guard-repo"
mkdir -p "$guard_repo"
git -C "$guard_repo" init -q
printf 'plan\n' > "$guard_repo/PLAN.md"
git -C "$guard_repo" add PLAN.md

commit_guard_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \\"x\\""}}\n' "$guard_repo" |
    node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
assert_contains "$commit_guard_output" '"permissionDecision":"deny"'
assert_contains "$commit_guard_output" 'must not be committed'

add_guard_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git add PLAN-e2e.md"}}\n' "$guard_repo" |
    node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
assert_contains "$add_guard_output" '"permissionDecision":"deny"'
assert_contains "$add_guard_output" 'must not be staged or committed'

git -C "$guard_repo" rm --cached -q PLAN.md
clean_commit_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \\"x\\""}}\n' "$guard_repo" |
    node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
if [ -n "$clean_commit_output" ]; then
  printf 'commits without staged PLAN files should pass the plan-commit-guard; got: %s\n' "$clean_commit_output" >&2
  exit 1
fi

archive_add_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git add docs/plan/20260704-slug.md"}}\n' "$guard_repo" |
    node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
if [ -n "$archive_add_output" ]; then
  printf 'adding docs/plan archives should pass the plan-commit-guard; got: %s\n' "$archive_add_output" >&2
  exit 1
fi

non_git_output="$(
  printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls PLAN.md"}}\n' "$guard_repo" |
    node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
if [ -n "$non_git_output" ]; then
  printf 'non-git commands should pass the plan-commit-guard; got: %s\n' "$non_git_output" >&2
  exit 1
fi

printf 'claude hooks smoke test: ok\n'
