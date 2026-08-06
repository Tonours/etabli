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

assert_empty() {
	local text="$1"
	local label="$2"

	if [ -n "$text" ]; then
		printf '%s should produce no output; got: %s\n' "$label" "$text" >&2
		exit 1
	fi
}

write_plan() {
	local status="$1"

	cat >"$TMP_DIR/PLAN.md" <<EOF
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
assert_contains "$bash_output" 'not proven read-only'

write_plan "READY"
ready_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/file.ts","content":"x"}}\n' "$TMP_DIR" "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
if [ -n "$ready_output" ]; then
	printf 'READY plans should allow implementation writes; got: %s\n' "$ready_output" >&2
	exit 1
fi

# Check-freeze through the real Claude PreToolUse entry (plan-ready-guard process).
cat >"$TMP_DIR/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY

## Checks
- command: bash tests/a.sh
- command: bash tests/b.sh

## Acceptance Criteria
- Given freeze, when weaken, then deny
PLAN
cat >"$TMP_DIR/plan-weaken.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY

## Checks
- command: bash tests/a.sh

## Acceptance Criteria
- Given freeze, when weaken, then deny
PLAN
freeze_payload="$(node --input-type=module -e '
import { readFileSync } from "node:fs";
const cwd = process.argv[1];
const content = readFileSync(process.argv[2], "utf8");
process.stdout.write(JSON.stringify({
  cwd,
  hook_event_name: "PreToolUse",
  tool_name: "Write",
  tool_input: { file_path: cwd + "/PLAN.md", content },
}) + "\n");
' "$TMP_DIR" "$TMP_DIR/plan-weaken.md")"
freeze_output="$(printf '%s' "$freeze_payload" | node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs")"
assert_contains "$freeze_output" '"permissionDecision":"deny"'
assert_contains "$freeze_output" 'check-freeze'

# Edit path through the same hook process
freeze_edit_payload="$(node --input-type=module -e '
const cwd = process.argv[1];
process.stdout.write(JSON.stringify({
  cwd,
  hook_event_name: "PreToolUse",
  tool_name: "Edit",
  tool_input: {
    file_path: cwd + "/PLAN.md",
    old_string: "- command: bash tests/b.sh\n",
    new_string: "",
  },
}) + "\n");
' "$TMP_DIR")"
freeze_edit_output="$(printf '%s' "$freeze_edit_payload" | node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs")"
assert_contains "$freeze_edit_output" '"permissionDecision":"deny"'
assert_contains "$freeze_edit_output" 'check-freeze'

bash_plan_payload="$(node --input-type=module -e '
const cwd = process.argv[1];
process.stdout.write(JSON.stringify({
  cwd,
  hook_event_name: "PreToolUse",
  tool_name: "Bash",
  tool_input: { command: "sed -i \"\" \"/b.sh/d\" PLAN.md" },
}) + "\n");
' "$TMP_DIR")"
bash_plan_output="$(printf '%s' "$bash_plan_payload" | node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs")"
assert_contains "$bash_plan_output" '"permissionDecision":"deny"'
assert_contains "$bash_plan_output" 'check-freeze'

# no_progress ledger mutate-deny through the same PreToolUse entry
mkdir -p "$TMP_DIR/.workflow/np-run"
printf '%s\n' '{"schema_version":2,"ts":"2026-08-01T00:00:00Z","run":"np-run","event":"no_progress","detail":{"check_or_hypothesis":"stuck","command":"bash tests/a.sh","attempts":2,"eliminated":["stuck"]}}' \
	>"$TMP_DIR/.workflow/np-run/events.jsonl"
cat >"$TMP_DIR/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY

## Checks
- command: bash tests/a.sh
PLAN
np_write_payload="$(node --input-type=module -e '
const cwd = process.argv[1];
process.stdout.write(JSON.stringify({
  cwd,
  hook_event_name: "PreToolUse",
  tool_name: "Write",
  tool_input: { file_path: cwd + "/src/blocked.ts", content: "x" },
}) + "\n");
' "$TMP_DIR")"
np_write_output="$(printf '%s' "$np_write_payload" | node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs")"
assert_contains "$np_write_output" '"permissionDecision":"deny"'
assert_contains "$np_write_output" 'no_progress'
np_escape_payload="$(node --input-type=module -e '
const cwd = process.argv[1];
process.stdout.write(JSON.stringify({
  cwd,
  hook_event_name: "PreToolUse",
  tool_name: "Bash",
  tool_input: { command: "scripts/workflow-event append --event blocked" },
}) + "\n");
' "$TMP_DIR")"
np_escape_output="$(printf '%s' "$np_escape_payload" | node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs")"
if [ -n "$np_escape_output" ]; then
	printf 'workflow-event escape under no_progress should allow; got: %s\n' "$np_escape_output" >&2
	exit 1
fi

# Read-only subagents keep Git/file inspection but deny shell mutation.
readonly_git_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git diff --stat"}}\n' "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
)"
assert_empty "$readonly_git_output" "read-only agent guard on git diff"

readonly_rtk_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk ls -la claude/hooks/read-only-agent-guard.mjs"}}\n' "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
)"
assert_empty "$readonly_rtk_output" "read-only agent guard on rtk-wrapped ls"

readonly_rtk_mutation_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rtk rm changed.txt"}}\n' "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
)"
assert_contains "$readonly_rtk_mutation_output" '"permissionDecision":"deny"'

readonly_mutation_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"printf x > changed.txt"}}\n' "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
)"
assert_contains "$readonly_mutation_output" '"permissionDecision":"deny"'
assert_contains "$readonly_mutation_output" 'agent is read-only'
assert_contains "$readonly_mutation_output" 'return to the parent'

guard_repo="$TMP_DIR/plan-commit-guard-repo"
mkdir -p "$guard_repo"
git -C "$guard_repo" init -q
cat >"$guard_repo/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY
PLAN
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

combined_commit_guard_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \\"x\\""}}\n' "$guard_repo" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$combined_commit_guard_output" '"permissionDecision":"deny"'
assert_contains "$combined_commit_guard_output" 'must not be committed'

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

for hook in plan-ready-guard plan-commit-guard read-only-agent-guard detect-adr-signal ledger-auto-emit; do
	malformed_output="$(printf 'not json{' | node "$ROOT_DIR/claude/hooks/$hook.mjs")"
	assert_empty "$malformed_output" "$hook on malformed stdin"
done

# PostToolUse ledger auto-emit path is registered
assert_contains "$(cat "$ROOT_DIR/claude/settings.workflow-hooks.json")" 'PostToolUse'
assert_contains "$(cat "$ROOT_DIR/claude/settings.workflow-hooks.json")" 'ledger-auto-emit.mjs'
pretool_count="$(jq '[.hooks.PreToolUse[] | .hooks[] | select(.command | contains("plan-ready-guard.mjs"))] | length' "$ROOT_DIR/claude/settings.workflow-hooks.json")"
[ "$pretool_count" -eq 1 ] || {
	printf 'expected one combined plan-ready PreToolUse hook, got %s\n' "$pretool_count" >&2
	exit 1
}
if jq -e '[.hooks.PreToolUse[] | .hooks[] | select(.command | contains("plan-commit-guard.mjs"))] | length > 0' "$ROOT_DIR/claude/settings.workflow-hooks.json" >/dev/null; then
	printf 'plan-commit-guard must be composed into the plan-ready hook\n' >&2
	exit 1
fi

printf 'claude hooks smoke test: ok\n'
