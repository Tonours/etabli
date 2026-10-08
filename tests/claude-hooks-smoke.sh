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
- Verify the guard.

## Workflow Contract
- Route: implement
- Role: implementer
- Stop condition: validated archive written and root PLAN.md deleted
- Required evidence: smoke test

## Acceptance Criteria
- Guard follows the plan status.

## Scope
- In: guard fixture
- Out: product code

## Facts And Assumptions
- Observed: temporary plan fixture
- Assumptions: none

## Requirement Trace
- Request -> fixture state -> no material gap -> guard output.

## Steps
1. Run the guard.

## Checks
- command: bash tests/claude-hooks-smoke.sh

## Risks
- None.

## Open Questions
- None
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

cat >"$TMP_DIR/PLAN.md" <<'PLAN'
# PLAN.md
## Meta
- Status: READY
PLAN
incomplete_ready_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/file.ts","content":"x"}}\n' "$TMP_DIR" "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$incomplete_ready_output" '"permissionDecision":"deny"'
assert_contains "$incomplete_ready_output" 'READY but incomplete'

cat >"$TMP_DIR/PLAN.md" <<'PLAN'
# PLAN.md
## Meta
- Status: DRAFT — needs review
PLAN
malformed_status_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/file.ts","content":"x"}}\n' "$TMP_DIR" "$TMP_DIR" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$malformed_status_output" '"permissionDecision":"deny"'
assert_contains "$malformed_status_output" 'PLAN.md is UNKNOWN'

# Check-freeze through the real Claude PreToolUse entry (plan-ready-guard process).
cat >"$TMP_DIR/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY

## Goal
- Verify check-freeze.

## Workflow Contract
- Route: implement
- Role: implementer
- Stop condition: fixture passes
- Required evidence: smoke output

## Scope
- In: plan guard
- Out: product code

## Facts And Assumptions
- Observed: temporary fixture
- Assumptions: none

## Requirement Trace
- Request -> check fixture -> no material gap -> guard denial.

## Steps
1. Exercise the guard.

## Checks
- command: bash tests/a.sh
- command: bash tests/b.sh

## Acceptance Criteria
- Given freeze, when weaken, then deny

## Risks
- None.

## Open Questions
- None
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

# a no_progress ledger no longer blocks mutations (guard removed in T2)
mkdir -p "$TMP_DIR/.workflow/np-run"
printf '%s\n' '{"schema_version":2,"ts":"2026-08-01T00:00:00Z","run":"np-run","event":"no_progress","detail":{"check_or_hypothesis":"stuck","command":"bash tests/a.sh","attempts":2,"eliminated":["stuck"]}}' \
	>"$TMP_DIR/.workflow/np-run/events.jsonl"
write_plan "READY"
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
if [ -n "$np_write_output" ]; then
	printf 'a no_progress ledger must not block writes under a READY plan; got: %s\n' "$np_write_output" >&2
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

readonly_guard_output() {
	local command="$1"
	node - "$TMP_DIR" "$command" <<'NODE' |
const [cwd, command] = process.argv.slice(2);
process.stdout.write(`${JSON.stringify({
  cwd,
  hook_event_name: "PreToolUse",
  tool_name: "Bash",
  tool_input: { command },
})}\n`);
NODE
		node "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs"
}

for unsafe_readonly_command in \
	"sed -n 'w changed.txt' input.txt" \
	"rtk sed -n 'w changed.txt' input.txt" \
	"sort --compress-program=sh input.txt" \
	"rtk sort --compress-program=sh input.txt" \
	"find . '-exec' touch changed.txt ';'"; do
	unsafe_readonly_output="$(readonly_guard_output "$unsafe_readonly_command")"
	assert_contains "$unsafe_readonly_output" '"permissionDecision":"deny"'
done

for allowed_readonly_command in \
	"gh api repos/o/r/pulls/42/files --paginate" \
	"gh api repos/o/r/pulls/42/comments --method GET" \
	"gh pr view 42 --json files,title" \
	"gh pr diff 42" \
	"gh auth status" \
	"awk '{ print \$1 }' registry.yaml" \
	"/bin/bash -n script.sh" \
	"/usr/bin/git diff HEAD" \
	"/usr/bin/cat input.txt" \
	"uniq -c input.txt" \
	"cat input.txt | uniq -c" \
	"rg -n --pre-glob '*.md' x docs" \
	"grep -n \"end\$\" input.txt" \
	"uniq -- input.txt" \
	"rg -n 'a*b' docs" \
	"cat docs/*.md" \
	"cd sub; git status" \
	"git merge-base main topic"; do
	allowed_readonly_output="$(readonly_guard_output "$allowed_readonly_command")"
	assert_empty "$allowed_readonly_output" "read-only agent guard allows $allowed_readonly_command"
done

for unsafe_readonly_command in \
	"gh pr create --title x" \
	"gh pr review 42 --approve" \
	"gh api repos/o/r/pulls/42/reviews --method POST --input r.json" \
	"gh api repos/o/r/issues/1/comments -f body=x" \
	"gh repo clone o/r" \
	"awk -f program.awk registry.yaml" \
	"awk '{ system(\"touch changed.txt\") }' input.txt" \
	"awk '{ print > \"changed.txt\" }' input.txt" \
	"awk '{ print | \"sh\" }' input.txt" \
	"cat input.txt; rm changed.txt" \
	"git status; git push --force" \
	"/bin/rm changed.txt" \
	"rg --pre rm x ." \
	"rg --pre=rm x ." \
	"rg --hostname-bin=sh x ." \
	"uniq A B" \
	"uniq - B" \
	"uniq A -B" \
	"script/test" \
	"./bin/cat input.txt" \
	"/tmp/bin/cat input.txt" \
	"gh api -XDELETE x" \
	"gh api -iXPOST repos/o/r/issues" \
	"gh api -fbody=x repos/o/r/issues/1/comments" \
	"rg''/script pattern file" \
	"cat''/x input.txt" \
	"rg \$'--pre=./script' pattern file" \
	"gh api \$'-XDELETE' repos/o/r" \
	"rg \${X:---pre=./s} pattern file" \
	"rg \$HOME" \
	"rg \"it's \$HOME\" docs" \
	"uniq -- -input output" \
	"uniq A --" \
	"rg {--pre=./script,pattern} file" \
	"gh api {-XDELETE,x}" \
	"uniq A*" \
	"rg pattern *" \
	"gh api repos/o/r/*" \
	"git diff *" \
	"find *" \
	"diff a*" \
	"node --check *" \
	"$(printf 'rg --pr\\\ne=./script x .')" \
	"$(printf 'rg "--hostname-b\\\nin=sh" x .')"; do
	unsafe_readonly_output="$(readonly_guard_output "$unsafe_readonly_command")"
	assert_contains "$unsafe_readonly_output" '"permissionDecision":"deny"'
done

guard_repo="$TMP_DIR/plan-commit-guard-repo"
mkdir -p "$guard_repo"
git -C "$guard_repo" init -q
cat >"$guard_repo/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY
## Goal
- Verify commit protection.
## Workflow Contract
- Route: implement
- Role: implementer
- Stop condition: fixture passes
- Required evidence: smoke output
## Acceptance Criteria
- PLAN remains uncommitted.
## Scope
- In: commit guard
- Out: product
## Facts And Assumptions
- Observed: temporary repository
- Assumptions: none
## Requirement Trace
- Request -> synthetic repository -> no material gap -> commit guard.
## Steps
1. Exercise the guard.
## Checks
- command: bash tests/claude-hooks-smoke.sh
## Risks
- None.
## Open Questions
- None
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

template_guard_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git add PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md"}}\n' "$guard_repo" |
		node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
case "$template_guard_output" in
	*"must not be staged or committed"*)
		printf 'claude hooks smoke: tracked plan templates must not trip the PLAN commit guard\n' >&2
		exit 1
		;;
esac

template_like_guard_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git add PLAN_TEMPLATE_DRAFT.md"}}\n' "$guard_repo" |
		node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
assert_contains "$template_like_guard_output" '"permissionDecision":"deny"'
assert_contains "$template_like_guard_output" 'must not be staged or committed'

combined_commit_guard_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \\"x\\""}}\n' "$guard_repo" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$combined_commit_guard_output" '"permissionDecision":"deny"'
assert_contains "$combined_commit_guard_output" 'must not be committed'

git -C "$guard_repo" rm --cached -q PLAN.md
printf 'template\n' >"$guard_repo/PLAN_TEMPLATE.md"
printf 'full template\n' >"$guard_repo/PLAN_TEMPLATE_FULL.md"
git -C "$guard_repo" add PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md
staged_template_commit_output="$(
	printf '{"cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \\"templates\\""}}\n' "$guard_repo" |
		node "$ROOT_DIR/claude/hooks/plan-commit-guard.mjs"
)"
if [ -n "$staged_template_commit_output" ]; then
	printf 'commits containing only tracked plan templates should pass the plan-commit-guard; got: %s\n' "$staged_template_commit_output" >&2
	exit 1
fi
git -C "$guard_repo" rm --cached -q PLAN_TEMPLATE.md PLAN_TEMPLATE_FULL.md

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

parity_dir="$TMP_DIR/no-comments-parity"
mkdir -p "$parity_dir"
printf '/**\n * Existing doc.\n */\nexport const a = 1;\n' >"$parity_dir/doc.ts"
ROOT_DIR="$ROOT_DIR" PARITY_DIR="$parity_dir" node --input-type=module <<'NODE'
import { spawnSync } from "node:child_process";
const root = process.env.ROOT_DIR;
const cwd = process.env.PARITY_DIR;
const { noCommentsGuardDecision } = await import(`${root}/workflow/runtime/no-comments-guard.mjs`);
const write = (name, content) => ({ tool_name: "Write", tool_input: { file_path: `${cwd}/${name}`, content } });
const edit = (old_string, new_string) => ({ tool_name: "Edit", tool_input: { file_path: `${cwd}/doc.ts`, old_string, new_string } });
const cases = [
  ["kept comment", edit(" * Existing doc.\n */\nexport const a = 1;", " * Existing doc.\n */\nexport const a = 2;"), "allow", "allow"],
  ["added comment", edit("export const a = 1;", "// added\nexport const a = 1;"), "deny", "deny"],
  ["shell length expansion", write("a.sh", "n=${#arr[@]}\n"), "deny", "allow"],
  ["css url", write("a.scss", ".a { background: url(http://example.test/x.png); }\n"), "deny", "allow"],
  ["regex literal", write("a.js", 'const p = s.replace(/\\/*$/, "");\n'), "deny", "allow"],
  ["ts-expect-error", write("b.ts", "// @ts-expect-error legacy\nconst x: number = 'a';\n"), "deny", "allow"],
  ["eslint directive", write("c.ts", "// eslint-disable-next-line no-console\nconsole.log(1);\n"), "deny", "allow"],
  ["copyright header", write("d.ts", "// Copyright 2026 Example\nexport {};\n"), "allow", "deny"],
  ["astro comment", write("e.astro", "---\n// note\n---\n"), "allow", "deny"],
  ["JSDoc continuation", edit(" * Existing doc.\n", " * Existing doc.\n * new line\n"), "allow", "deny"],
];
let failed = 0;
for (const [label, event, sharedExpected, claudeExpected] of cases) {
  const shared = noCommentsGuardDecision({ cwd, ...event }) ? "deny" : "allow";
  const run = spawnSync("node", [`${root}/claude/hooks/no-comments-guard.mjs`], { input: JSON.stringify({ cwd, ...event }), encoding: "utf8" });
  const claude = run.stdout.includes('"permissionDecision":"deny"') ? "deny" : "allow";
  if (shared !== sharedExpected || claude !== claudeExpected) {
    console.error(`no-comments parity ${label}: shared ${shared} (want ${sharedExpected}), claude ${claude} (want ${claudeExpected})`);
    failed += 1;
  }
}
if (failed) process.exit(1);
NODE

ops_free="$TMP_DIR/ops-free"
mkdir -p "$ops_free"
ops_ask_output="$(
	printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git push --force origin feature-x"}}\n' "$ops_free" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_contains "$ops_ask_output" '"permissionDecision":"ask"'
assert_contains "$ops_ask_output" 'ops-stop: git push --force without a lease'
ops_branch_output="$(
	printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git push -u origin feature-x"}}\n' "$ops_free" |
		node "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs"
)"
assert_empty "$ops_branch_output" "plan-ready-guard on a feature-branch push"

broken_hooks="$TMP_DIR/broken-hooks"
broken_plan="$TMP_DIR/broken-plan"
broken_free="$TMP_DIR/broken-free"
mkdir -p "$broken_hooks" "$broken_plan" "$broken_free"
cp "$ROOT_DIR/claude/hooks/plan-ready-guard.mjs" "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs" "$broken_hooks/"
printf '%s\n' '## Meta' '- Status: DRAFT' >"$broken_plan/PLAN.md"

broken_plan_output="$(
	printf '{"cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s/x.ts","content":"x"}}\n' "$broken_plan" "$broken_plan" |
		node "$broken_hooks/plan-ready-guard.mjs" 2>/dev/null
)"
assert_contains "$broken_plan_output" '"permissionDecision":"deny"'
assert_contains "$broken_plan_output" 'scripts/deploy-agent-workflow --apply'

broken_push_output="$(
	printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"git push origin main"}}\n' "$broken_free" |
		node "$broken_hooks/plan-ready-guard.mjs" 2>/dev/null
)"
assert_contains "$broken_push_output" '"permissionDecision":"deny"'

broken_free_output="$(
	printf '{"cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s/x.ts","content":"x"}}\n' "$broken_free" "$broken_free" |
		node "$broken_hooks/plan-ready-guard.mjs" 2>"$TMP_DIR/broken-free.err"
)"
assert_empty "$broken_free_output" "broken plan-ready-guard without a plan or push/rm"
assert_contains "$(cat "$TMP_DIR/broken-free.err")" 'plan-ready-guard failed'

broken_reader_output="$(
	printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"ls"}}\n' "$broken_free" |
		node "$broken_hooks/read-only-agent-guard.mjs"
)"
assert_contains "$broken_reader_output" '"permissionDecision":"deny"'
assert_contains "$broken_reader_output" 'Bash stays blocked'

for hook in plan-ready-guard plan-commit-guard read-only-agent-guard detect-adr-signal ledger-auto-emit session-state; do
	malformed_output="$(printf 'not json{' | node "$ROOT_DIR/claude/hooks/$hook.mjs")"
	assert_empty "$malformed_output" "$hook on malformed stdin"
done

session_state_dir="$TMP_DIR/session-state"
mkdir -p "$session_state_dir/.workflow/state-run" "$TMP_DIR/no-state"
printf '%s\n' '## Meta' '- Subject: session state fixture' '- Status: READY' '' '## Goal' 'Resume after compaction.' >"$session_state_dir/PLAN.md"
printf '%s\n' '{"schema_version":2,"ts":"2026-09-01T00:00:00Z","event":"adversary_completed","run":"state-run","detail":{"mode":"plan","verdict":"CHALLENGED","accepted_findings":[{"finding":"keep the fixture honest","blocking":true}],"rejected_findings":[]}}' '{"schema_version":2,"ts":"2026-09-01T00:01:00Z","event":"handoff","run":"state-run","detail":{"branch":"b","sha":"abc","done":["slice one"],"pending":["slice two","slice three"],"next_action":"run slice two checks","do_not_redo":["abandoned parser"]}}' >"$session_state_dir/.workflow/state-run/events.jsonl"
printf '%s\n' '{"schema_version":1,"run":"state-run"}' >"$session_state_dir/.workflow/active-run.json"
session_state_output="$(jq -nc --arg cwd "$session_state_dir" '{cwd:$cwd,hook_event_name:"SessionStart",reason:"compact"}' | node "$ROOT_DIR/claude/hooks/session-state.mjs")"
session_state_context="$(printf '%s' "$session_state_output" | jq -r '.hookSpecificOutput.additionalContext')"
assert_contains "$(printf '%s' "$session_state_output" | jq -r '.hookSpecificOutput.hookEventName')" 'SessionStart'
assert_contains "$session_state_context" 'When compacting, keep the root `PLAN.md` subject and status'
assert_contains "$session_state_context" 'PLAN.md: session state fixture (Status: READY)'
assert_contains "$session_state_context" 'run slice two checks'
assert_contains "$session_state_context" 'abandoned parser'
assert_contains "$session_state_context" 'slice three'
assert_contains "$session_state_context" 'keep the fixture honest'
plan_only_dir="$TMP_DIR/session-plan-only"
mkdir -p "$plan_only_dir"
printf '%s\n' '## Meta' '- Subject: plan only' '- Status: DRAFT' >"$plan_only_dir/PLAN.md"
plan_only_context="$(jq -nc --arg cwd "$plan_only_dir" '{cwd:$cwd,hook_event_name:"SessionStart",reason:"resume"}' | node "$ROOT_DIR/claude/hooks/session-state.mjs" | jq -r '.hookSpecificOutput.additionalContext')"
assert_contains "$plan_only_context" 'PLAN.md: plan only (Status: DRAFT)'
empty_state_output="$(jq -nc --arg cwd "$TMP_DIR/no-state" '{cwd:$cwd,hook_event_name:"SessionStart",reason:"resume"}' | node "$ROOT_DIR/claude/hooks/session-state.mjs")"
assert_empty "$empty_state_output" "session-state without plan or ledger"
jq -e '[.hooks.SessionStart[] | select(.matcher == "compact|resume") | .hooks[] | select(.command | contains("session-state.mjs"))] | length == 1' "$ROOT_DIR/claude/settings.workflow-hooks.json" >/dev/null || {
	printf 'settings.workflow-hooks.json must wire session-state on SessionStart compact|resume\n' >&2
	exit 1
}

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
jq -e '[.hooks.PreToolUse[] | select(.matcher == "Write|Edit|MultiEdit") | .hooks[] | select(.command | contains("no-comments-guard.mjs"))] | length == 1' "$ROOT_DIR/claude/settings.workflow-hooks.json" >/dev/null || {
	printf 'settings.workflow-hooks.json must wire no-comments-guard on Write|Edit|MultiEdit\n' >&2
	exit 1
}
jq -e '[.hooks.UserPromptSubmit[] | .hooks[] | select(.command | contains("correction-emit.mjs"))] | length == 1' "$ROOT_DIR/claude/settings.workflow-hooks.json" >/dev/null || {
	printf 'settings.workflow-hooks.json must wire correction-emit on UserPromptSubmit\n' >&2
	exit 1
}
jq -e '[.hooks.Notification[] | .hooks[] | select(.command | contains("notification-classify.mjs"))] | length == 1' "$ROOT_DIR/claude/settings.workflow-hooks.json" >/dev/null || {
	printf 'settings.workflow-hooks.json must wire notification-classify on Notification\n' >&2
	exit 1
}
no_comments="$ROOT_DIR/claude/hooks/no-comments-guard.mjs"
denied=$(jq -nc --arg cwd "$TMP_DIR" '{cwd:$cwd,tool_name:"Write",tool_input:{file_path:"src/a.ts",content:("/" + "/ note\nconst a = 1\n")}}' | node "$no_comments")
[ "$(printf '%s' "$denied" | jq -r '.hookSpecificOutput.permissionDecision')" = deny ] || {
	printf 'no-comments-guard must deny a write that adds a comment, got %s\n' "$denied" >&2
	exit 1
}
clean=$(jq -nc --arg cwd "$TMP_DIR" '{cwd:$cwd,tool_name:"Write",tool_input:{file_path:"src/a.ts",content:("const url = \"http:" + "/" + "/x\"\n")}}' | node "$no_comments")
[ -z "$clean" ] || {
	printf 'no-comments-guard must pass comment markers inside strings, got %s\n' "$clean" >&2
	exit 1
}
if jq -r '.. | .command? // empty' "$ROOT_DIR/claude/settings.workflow-hooks.json" | grep -F '"$HOME/.claude/hooks/' >/dev/null; then
	printf 'hook commands must resolve through CLAUDE_CONFIG_DIR, not a bare $HOME/.claude\n' >&2
	exit 1
fi

rtk_guard="$ROOT_DIR/claude/hooks/rtk-guard.mjs"
fake_rtk_dir="$TMP_DIR/fake-rtk"
mkdir -p "$fake_rtk_dir"
cat >"$fake_rtk_dir/rtk" <<'EOF'
#!/bin/sh
printf 'called\n' >>"$RTK_CALLS"
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":{"command":"rtk git status"}}}'
EOF
chmod +x "$fake_rtk_dir/rtk"
export RTK_CALLS="$TMP_DIR/rtk-calls"
: >"$RTK_CALLS"
node_bin="$(node -p process.execPath)"
for data_command in 'git diff > out.diff' 'cat a > b' 'git diff | wc -l'; do
	data_out="$(jq -nc --arg c "$data_command" '{tool_name:"Bash",tool_input:{command:$c}}' | PATH="$fake_rtk_dir:$PATH" "$node_bin" "$rtk_guard")"
	assert_empty "$data_out" "rtk-guard on data-flow command '$data_command'"
done
[ ! -s "$RTK_CALLS" ] || {
	printf 'rtk-guard must not call rtk for data-flow commands\n' >&2
	exit 1
}
display_out="$(jq -nc '{tool_name:"Bash",tool_input:{command:"git status"}}' | PATH="$fake_rtk_dir:$PATH" "$node_bin" "$rtk_guard")"
assert_contains "$display_out" '"command":"rtk git status"'
missing_out="$(jq -nc '{tool_name:"Bash",tool_input:{command:"git status"}}' | PATH="$(dirname "$node_bin")" "$node_bin" "$rtk_guard")"
assert_empty "$missing_out" "rtk-guard without rtk on PATH"

rtk_home="$TMP_DIR/rtk-migration-home"
mkdir -p "$rtk_home/.claude"
jq -n '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:"rtk hook claude"}]},{matcher:"Bash",hooks:[{type:"command",command:"rtk hook claude --ultra-compact"}]},{matcher:"Bash",hooks:[{type:"command",command:"rtk hook claude\t--ultra-compact"}]},{matcher:"Bash",hooks:[{type:"command",command:"/opt/homebrew/bin/rtk hook claude"}]},{matcher:"Bash",hooks:[{type:"command",command:"rtk hook claude && node audit.mjs"}]},{matcher:"Bash",hooks:[{type:"command",command:"\"rtk\" hook \"claude\""}]},{matcher:"Bash",hooks:[{type:"command",command:"rtk --verbose hook claude"}]},{matcher:"Bash",hooks:[{type:"command",command:"rtk hook claude \"$(node audit-subst.mjs)\""}]},{matcher:"Bash",hooks:[{type:"command",command:"rtk \"--x=`node audit-tick.mjs`\" hook claude"}]}]}}' >"$rtk_home/.claude/settings.json"
obf_home="$TMP_DIR/rtk-obfuscated-home"
mkdir -p "$obf_home/.claude"
jq -n --arg c "r''tk hook claude && :" --arg w "sh -c \"r''tk hook claude\"" --arg n "$(printf 'sh -c "r\\\ntk hook claude"')" --arg m "$(printf "sh -c '#x\\\\\nr\"\"tk hook claude'")" --arg k "$(printf "#/usr/bin/rtk hook claude --'\nprintf audit-comment\n#'")" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$c}]},{matcher:"^B",hooks:[{type:"command",command:"rtk hook claude && :"}]},{matcher:"Bash",hooks:[{type:"command",command:$w}]},{matcher:"Bash",hooks:[{type:"command",command:$n}]},{matcher:"Bash",hooks:[{type:"command",command:$m}]},{matcher:"Bash",hooks:[{type:"command",command:$k}]},{matcher:"Bash",hooks:[{type:"command",command:"RTK hook claude"}]}]}}' >"$obf_home/.claude/settings.json"
"$ROOT_DIR/scripts/claude-hooks-merge" --home "$obf_home" >/dev/null
assert_contains "$(jq -r '.. | .command? // empty' "$obf_home/.claude/settings.json")" "r''tk hook claude && :"
if "$ROOT_DIR/scripts/claude-hooks-check" --home "$obf_home" >"$TMP_DIR/rtk-obf-check.txt" 2>&1; then
	printf 'claude-hooks-check must fail while a quoted rtk token hides a rewriting hook\n' >&2
	exit 1
fi
assert_contains "$(cat "$TMP_DIR/rtk-obf-check.txt")" 'calls rtk outside rtk-guard'
assert_contains "$(cat "$TMP_DIR/rtk-obf-check.txt")" 'PreToolUse/^B: rtk hook claude && :'
assert_contains "$(cat "$TMP_DIR/rtk-obf-check.txt")" "PreToolUse/Bash: sh -c \"r''tk hook claude\""
jq -r '.. | .command? // empty' "$obf_home/.claude/settings.json" | grep -Fq 'printf audit-comment' || {
	printf 'a commented multiline hook must never be retired as a simple rtk call\n' >&2
	exit 1
}
[ "$(grep -c 'calls rtk outside rtk-guard' "$TMP_DIR/rtk-obf-check.txt")" -eq 7 ] || {
	printf 'a backslash-newline continuation inside an rtk hook must be refused too\n' >&2
	exit 1
}
nonbash_home="$TMP_DIR/rtk-nonbash-home"
mkdir -p "$nonbash_home/.claude"
jq -n '{hooks:{PreToolUse:[{matcher:"Write|Edit",hooks:[{type:"command",command:"rtk gain --history"}]}]}}' >"$nonbash_home/.claude/settings.json"
"$ROOT_DIR/scripts/claude-hooks-check" --home "$nonbash_home" >"$TMP_DIR/rtk-nonbash-check.txt" 2>&1 || :
if grep -Fq 'calls rtk outside rtk-guard' "$TMP_DIR/rtk-nonbash-check.txt"; then
	printf 'a PreToolUse hook whose matcher cannot match Bash must not be refused\n' >&2
	exit 1
fi
"$ROOT_DIR/scripts/claude-hooks-merge" --home "$rtk_home" >/dev/null || {
	printf 'claude-hooks-merge failed on an rtk-hooked settings file\n' >&2
	exit 1
}
migrated_commands="$(jq -r '.. | .command? // empty' "$rtk_home/.claude/settings.json")"
assert_contains "$migrated_commands" 'rtk hook claude && node audit.mjs'
assert_contains "$migrated_commands" 'audit-subst.mjs'
assert_contains "$migrated_commands" 'audit-tick.mjs'
if printf '%s\n' "$migrated_commands" | grep -v 'audit' | grep -Eq '(^|/)rtk[[:space:]]+hook[[:space:]]+claude'; then
	printf 'claude-hooks-merge must retire the raw rtk hook and its option variants\n' >&2
	exit 1
fi
assert_contains "$migrated_commands" 'hooks/rtk-guard.mjs'
if "$ROOT_DIR/scripts/claude-hooks-check" --home "$rtk_home" >"$TMP_DIR/rtk-check.txt" 2>&1; then
	printf 'claude-hooks-check must fail while a custom hook calls rtk hook claude outside rtk-guard\n' >&2
	exit 1
fi
assert_contains "$(cat "$TMP_DIR/rtk-check.txt")" 'calls rtk outside rtk-guard'
cp "$rtk_home/.claude/settings.json" "$TMP_DIR/rtk-migrated.json"
"$ROOT_DIR/scripts/claude-hooks-merge" --home "$rtk_home" >/dev/null
cmp -s "$rtk_home/.claude/settings.json" "$TMP_DIR/rtk-migrated.json" || {
	printf 'claude-hooks-merge must be idempotent after the rtk migration\n' >&2
	exit 1
}

benign_home="$TMP_DIR/rtk-benign-home"
mkdir -p "$benign_home/.claude"
jq -n '{hooks:{Stop:[{hooks:[{type:"command",command:"echo '"'"'rtk hook claude is deprecated'"'"'"}]}]}}' >"$benign_home/.claude/settings.json"
"$ROOT_DIR/scripts/claude-hooks-merge" --home "$benign_home" >/dev/null 2>&1
assert_contains "$(jq -r '.. | .command? // empty' "$benign_home/.claude/settings.json")" "echo 'rtk hook claude is deprecated'"
"$ROOT_DIR/scripts/claude-hooks-check" --home "$benign_home" >"$TMP_DIR/benign-check.txt" 2>&1 || true
if grep -q 'outside rtk-guard' "$TMP_DIR/benign-check.txt"; then
	printf 'claude-hooks-check must not refuse rtk text outside Bash PreToolUse hooks\n' >&2
	exit 1
fi
prefixed_home="$TMP_DIR/rtk-prefixed-home"
mkdir -p "$prefixed_home/.claude"
for prefixed in 'command -- rtk hook claude' "sh -lc 'rtk hook claude'" 'env -i PATH=/usr/bin rtk hook claude'; do
	jq -n --arg c "$prefixed" '{hooks:{PreToolUse:[{matcher:"Bash",hooks:[{type:"command",command:$c}]}]}}' >"$prefixed_home/.claude/settings.json"
	"$ROOT_DIR/scripts/claude-hooks-merge" --home "$prefixed_home" >/dev/null 2>&1
	if "$ROOT_DIR/scripts/claude-hooks-check" --home "$prefixed_home" >"$TMP_DIR/prefixed-check.txt" 2>&1; then
		printf 'claude-hooks-check must refuse %s\n' "$prefixed" >&2
		exit 1
	fi
	assert_contains "$(cat "$TMP_DIR/prefixed-check.txt")" 'calls rtk outside rtk-guard'
done

correction_proj="$TMP_DIR/correction-proj"
mkdir -p "$correction_proj/scripts" "$correction_proj/.workflow/corr-run"
cp "$ROOT_DIR/scripts/workflow-event" "$correction_proj/scripts/"
cp -R "$ROOT_DIR/scripts/lib" "$correction_proj/scripts/"
printf '%s\n' '{"schema_version":2,"ts":"2026-09-29T00:00:00Z","event":"plan_created","run":"corr-run","detail":{"path":"PLAN.md","status":"READY"}}' >"$correction_proj/.workflow/corr-run/events.jsonl"
jq -nc --arg cwd "$correction_proj" '{cwd:$cwd,session_id:"smoke-sess",prompt:"initial instruction"}' | node "$ROOT_DIR/claude/hooks/correction-emit.mjs"
jq -nc --arg cwd "$correction_proj" '{cwd:$cwd,session_id:"smoke-sess",prompt:"non fais plutot ceci"}' | node "$ROOT_DIR/claude/hooks/correction-emit.mjs"
correction_ledger="$correction_proj/.workflow/corr-run/events.jsonl"
grep -Fq '"event":"correction"' "$correction_ledger" || {
	printf 'correction-emit must append a correction on the second prompt via the locked CLI\n' >&2
	exit 1
}
if grep -Fq 'fais plutot ceci' "$correction_ledger"; then
	printf 'correction ledger must never contain prompt text\n' >&2
	exit 1
fi
"$correction_proj/scripts/workflow-event" --dir "$correction_proj/.workflow" validate corr-run >/dev/null || {
	printf 'fixture ledger with hook-appended correction must validate\n' >&2
	exit 1
}

jq -nc --arg cwd "$correction_proj" '{cwd:$cwd,session_id:"smoke-sess",notification_type:"permission_prompt",message:"Claude needs your permission"}' | node "$ROOT_DIR/claude/hooks/notification-classify.mjs"
grep -Fq '"consent_class":"permission_request"' "$correction_ledger" || {
	printf 'notification-classify must emit permission_request for permission_prompt\n' >&2
	exit 1
}
jq -nc --arg cwd "$correction_proj" '{cwd:$cwd,session_id:"smoke-sess",notification_type:"idle_prompt",message:"Claude is waiting for your input"}' | node "$ROOT_DIR/claude/hooks/notification-classify.mjs"
grep -Fq '"consent_class":"input_request"' "$correction_ledger" || {
	printf 'notification-classify must emit input_request for idle_prompt\n' >&2
	exit 1
}
before_notif="$(grep -c human_checkpoint "$correction_ledger")"
jq -nc --arg cwd "$correction_proj" '{cwd:$cwd,session_id:"smoke-sess",notification_type:"future_unknown_type",message:"x"}' | node "$ROOT_DIR/claude/hooks/notification-classify.mjs"
after_notif="$(grep -c human_checkpoint "$correction_ledger")"
[ "$after_notif" = "$before_notif" ] || {
	printf 'notification-classify must abstain on unknown notification types\n' >&2
	exit 1
}
"$correction_proj/scripts/workflow-event" --dir "$correction_proj/.workflow" validate corr-run >/dev/null || {
	printf 'fixture ledger with classified checkpoints must validate\n' >&2
	exit 1
}

printf 'claude hooks smoke test: ok\n'
