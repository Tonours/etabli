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
	"awk '{ print \$1 }' registry.yaml" \
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

read_only_probes=(
	"rtk test touch x"
	"rtk test rm x"
	"echo 'a\' ; rm x ; echo 'b\'"
	$'git status # \'\nrm x\n# \''
	"echo =(touch x)"
	"ls *(e:'touch p':)"
	"node --check --require ./evil.js a.js"
	"node --check --import ./evil.mjs a.js"
	"gh auth status --show-token"
	"gh auth status -t"
	"jq -n env"
	"awk -fevil.awk f"
	"gh auth token"
	"jq -n \$ENV"
	"git -c core.pager=touch\\ x log"
	"find . -delete"
	"bash -n -i -c 'touch x'"
	"echo env | jq -nf /dev/stdin"
	"bash -n +n x"
	"git grep --open-files-in-page=touch x"
	"gh auth status --show-token=true"
	"git grep -nOtouch x"
	"rtk grep x f -- --pre=touch"
	"test -v 'BASH_VERSINFO[\$(touch x)]'"
	"gh pr view 1 -w"
	"git --help --web status"
	"git log --show-signature -1"
	"echo \"\$[BASH_VERSINFO[\\\$(touch x)]]\""
	"git log -1 --format=%GG"
	"git log --help"
	"diff -l a b"
	"rg -z foo a.gz"
)
read_only_controls=(
	"git status"
	"rtk git log --oneline -3"
	"grep -n 'a#b' file"
	"node --version"
	"find . \\( -name a -o -name b \\) -print"
	"git log --format='%h (%s)' -3"
	"gh pr view 1"
	"jq '.a' f.json"
	"ls -la"
	"git log --output-indicator-new=x"
	"git diff --no-ext-diff"
	"git grep -eFOO x"
	"git log -GTODO"
)
probes_allowed=0
for probe in "${read_only_probes[@]}"; do
	if ! readonly_guard_output "$probe" | grep -Fq '"permissionDecision":"deny"'; then
		printf 'read-only guard allowed probe: %s\n' "$probe" >&2
		probes_allowed=$((probes_allowed + 1))
	fi
done
controls_denied=0
for control in "${read_only_controls[@]}"; do
	if ! control_output="$(readonly_guard_output "$control")" || [ -n "$control_output" ]; then
		printf 'read-only guard denied control: %s\n' "$control" >&2
		controls_denied=$((controls_denied + 1))
	fi
done
[ "$probes_allowed" -eq 0 ] && [ "$controls_denied" -eq 0 ] || {
	printf 'read-only guard: %d of %d probes allowed, %d of %d controls denied\n' \
		"$probes_allowed" "${#read_only_probes[@]}" "$controls_denied" "${#read_only_controls[@]}" >&2
	exit 1
}

parity_dir="$TMP_DIR/no-comments-parity"
mkdir -p "$parity_dir"
printf '/**\n * Existing doc.\n */\nexport const a = 1;\n' >"$parity_dir/doc.ts"
printf "const x = 1; // don't\nconst y = 2;\n" >"$parity_dir/apos.ts"
ROOT_DIR="$ROOT_DIR" PARITY_DIR="$parity_dir" node --input-type=module <<'NODE'
import { spawnSync } from "node:child_process";
const root = process.env.ROOT_DIR;
const cwd = process.env.PARITY_DIR;
const { noCommentsGuardDecision } = await import(`${root}/workflow/runtime/no-comments-guard.mjs`);
const write = (name, content) => ({ tool_name: "Write", tool_input: { file_path: `${cwd}/${name}`, content } });
const edit = (old_string, new_string) => ({ tool_name: "Edit", tool_input: { file_path: `${cwd}/doc.ts`, old_string, new_string } });
const multiEdit = (edits) => ({ tool_name: "MultiEdit", tool_input: { file_path: `${cwd}/doc.ts`, edits } });
const cases = [
  ["kept comment", edit(" * Existing doc.\n */\nexport const a = 1;", " * Existing doc.\n */\nexport const a = 2;"), "allow"],
  ["added comment", edit("export const a = 1;", "// added\nexport const a = 1;"), "deny"],
  ["shell length expansion", write("a.sh", "n=${#arr[@]}\n"), "allow"],
  ["css url", write("a.scss", ".a { background: url(http://example.test/x.png); }\n"), "allow"],
  ["regex literal", write("a.js", 'const p = s.replace(/\\/*$/, "");\n'), "allow"],
  ["ts-expect-error", write("b.ts", "// @ts-expect-error legacy\nconst x: number = 'a';\n"), "allow"],
  ["eslint directive", write("c.ts", "// eslint-disable-next-line no-console\nconsole.log(1);\n"), "allow"],
  ["copyright header", write("d.ts", "// Copyright 2026 Example\nexport {};\n"), "allow"],
  ["astro comment", write("e.astro", "---\n// note\n---\n"), "deny"],
  ["JSDoc continuation", edit(" * Existing doc.\n", " * Existing doc.\n * new line\n"), "deny"],
  ["duplicated comment write", write("doc.ts", "/**\n * Existing doc.\n */\n/**\n * Existing doc.\n */\nexport const a = 1;\n"), "deny"],
  ["duplicated comment edit", edit("export const a = 1;", "export const a = 1;\n/**\n * Existing doc.\n */"), "deny"],
  ["duplicated comment multiedit", multiEdit([{ old_string: "export const a = 1;", new_string: "export const a = 1;\n/** Existing doc. */" }, { old_string: "/** Existing doc. */", new_string: "/**\n * Existing doc.\n */" }]), "deny"],
  ["line comment in ts", write("f.ts", "// note\nexport {};\n"), "deny"],
  ["hash comment in py", write("g.py", "# note\nx = 1\n"), "deny"],
  ["block comment in css", write("h.css", "/* x */\n.a { color: red; }\n"), "deny"],
  ["comment after apostrophe", write("apos.ts", "const x = 1; // don't\nconst y = 2;\n// brand new note\n"), "deny"],
  ["comment after string with slash", write("j.ts", 'const x = "(/)"; // added note\n'), "deny"],
  ["python glued comment", write("k.py", "x = 1# added note\n"), "deny"],
  ["shell multiline string", write("l.sh", "data='first\n# data\nlast'\n"), "allow"],
  ["sql multiline string", write("o.sql", "SELECT 'first\n-- data\nlast';\n"), "allow"],
  ["shell ansi-c string", write("p.sh", "echo $'it\\'s'\n# added note\n"), "deny"],
  ["shell substitution comment", write("q.sh", 'x="$(\n  printf hi # added note\n)"\n'), "deny"],
  ["sql escaped string then comment", write("r.sql", "SELECT E'it\\'s';\n-- added note\n"), "deny"],
  ["shell escaped paren in substitution", write("t.sh", 'm="$(grep -o \\( "$f")\n# data"\n'), "allow"],
  ["shell heredoc in substitution", write("u.sh", "t=\"$(cat <<'TEXT'\n# Heading\nTEXT\n)\"\n"), "allow"],
  ["shell unquoted heredoc substitution comment", write("v.sh", "cat <<EOF\n$(\n  printf hi # added note\n)\nEOF\n"), "deny"],
  ["sql double-quoted backslash then comment", write("x.sql", 'SELECT e"path\\" FROM src; -- added note\n'), "deny"],
  ["shell unquoted heredoc apostrophe then comment", write("y.sh", "cat <<EOF\nDon't panic\nEOF\n# added note\n"), "deny"],
  ["shell unquoted heredoc data", write("z.sh", "cat <<EOF\n# Heading\nEOF\n"), "allow"],
  ["shell backtick in heredoc", write("ac.sh", "cat <<EOF\n`printf hi # added note\n`\nEOF\n"), "deny"],
  ["shell case inside a file name", write("ad.sh", 'r="$(cat test-case.json)"\n# added note\n'), "deny"],
  ["shell heredoc data after substitution", write("ae.sh", "cat <<EOF\n$(cat test-case.json)\n# Heading\nEOF\n"), "allow"],
  ["shell esac glued to redirect", write("ag.sh", 'r="$(case "$m" in\n  prod) printf p;;\nesac>/dev/null)"\n# added note\n'), "deny"],
  ["shell case variable in arithmetic", write("ah.sh", 'v="$((case>0))"\n# added note\n'), "deny"],
  ["shell case word as a pattern", write("aj.sh", 't="$(( $(case "$q" in (case) printf 12;; (*) printf 1;; esac) + 1 ))"\n# added note\n'), "deny"],
  ["sql block comment", write("ak.sql", "SELECT 1;\n/* added\nnote */\n"), "deny"],
  ["lua long string data", write("al.lua", "s = [[\n-- data\n]]\n"), "allow"],
  ["sql dollar-quoted data", write("au.sql", "SELECT $$/* data */$$;\n"), "allow"],
  ["ruby is not guarded", write("bn.rb", "# added note\nx = 1\n"), "allow"],
  ["license block", write("ba.ts", "/*\n * Copyright 2026 Example\n * Licensed under the MIT License.\n */\nexport {};\n"), "allow"],
  ["triple-slash reference", write("bb.ts", '/// <reference types="node" />\nexport {};\n'), "allow"],
  ["ts-check", write("bc.js", "// @ts-check\nexport {};\n"), "allow"],
  ["python type ignore", write("bd.py", "x = f()  # type: ignore\n"), "allow"],
  ["python noqa", write("be.py", "import os  # noqa: F401\n"), "allow"],
  ["go embed", write("bf.go", "//go:embed static\nvar files embed.FS\n"), "allow"],
  ["shellcheck directive", write("bg.sh", "# shellcheck disable=SC2086\necho $x\n"), "allow"],
  ["regex literal at line start", write("bh.js", "/\\/\\//.test(s);\n"), "allow"],
  ["regex literal after return", write("bi.js", "function f() {\n  return /\\/\\//;\n}\n"), "allow"],
  ["regex literal after arrow", write("bj.js", "const f = () => /\\/\\//;\n"), "allow"],
  ["slashes in a nested template", write("bk.ts", "const u = `${`//`}`;\n"), "allow"],
  ["comment after a nested template", write("bl.ts", "const s = `${'`'}`; // added note\n"), "deny"],
  ["comment inside a template expression", write("bm.ts", "const s = `${a /* added note */}`;\n"), "deny"],
  ["replace_all comment", { tool_name: "Edit", tool_input: { file_path: `${cwd}/apos.ts`, old_string: "const", new_string: "const/* added */", replace_all: true } }, "deny"],
];
let failed = 0;
for (const [label, event, expected] of cases) {
  const shared = noCommentsGuardDecision({ cwd, ...event }) ? "deny" : "allow";
  const run = spawnSync("node", [`${root}/claude/hooks/no-comments-guard.mjs`], { input: JSON.stringify({ cwd, ...event }), encoding: "utf8" });
  const claude = run.status === 0 ? (run.stdout.includes('"permissionDecision":"deny"') ? "deny" : "allow") : `exit ${run.status}`;
  if (shared !== expected || claude !== expected) {
    console.error(`no-comments parity ${label}: shared ${shared}, claude ${claude}, want ${expected}`);
    failed += 1;
  }
}
if (failed) process.exit(1);
NODE

ROOT_DIR="$ROOT_DIR" PARITY_DIR="$parity_dir" node --input-type=module <<'NODE'
const { noCommentsGuardDecision } = await import(`${process.env.ROOT_DIR}/workflow/runtime/no-comments-guard.mjs`);
const write = (content) => ({ cwd: process.env.PARITY_DIR, tool_name: "Write", tool_input: { file_path: "long.sh", content } });
const started = performance.now();
const long = noCommentsGuardDecision(write(`echo ${"ab ".repeat(53334)}\n`));
const elapsed = performance.now() - started;
if (long || elapsed > 150) {
  console.error(`no-comments lexer: 160k one-line write took ${Math.round(elapsed)} ms (want under 150) or was denied`);
  process.exit(1);
}
let nested;
try {
  nested = noCommentsGuardDecision(write(`x=${'"$('.repeat(5000)}\n# added note\n`));
} catch (error) {
  console.error(`no-comments lexer: 5000 nested substitutions threw ${error.name}`);
  process.exit(1);
}
if (nested) {
  console.error("no-comments lexer: past the nesting cap the write must be allowed");
  process.exit(1);
}
NODE

broken_hooks="$TMP_DIR/broken-hooks"
broken_free="$TMP_DIR/broken-free"
mkdir -p "$broken_hooks" "$broken_free"
cp "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs" "$broken_hooks/"

broken_reader_output="$(
	printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"ls"}}\n' "$broken_free" |
		node "$broken_hooks/read-only-agent-guard.mjs"
)"
assert_contains "$broken_reader_output" '"permissionDecision":"deny"'
assert_contains "$broken_reader_output" 'Bash stays blocked'

malformed_status=0
printf 'not json{' | node "$ROOT_DIR/claude/hooks/read-only-agent-guard.mjs" >/dev/null 2>"$TMP_DIR/malformed.err" || malformed_status=$?
[ "$malformed_status" -eq 2 ] || {
	printf 'read-only-agent-guard must exit 2 on malformed stdin, got %s\n' "$malformed_status" >&2
	exit 1
}
assert_contains "$(cat "$TMP_DIR/malformed.err")" 'read-only-agent-guard'

frontmatter_command="$(sed -n 's/^ *command: //p' "$ROOT_DIR/claude/scopes/shared/agents/scout.md")"
missing_guard_status=0
printf '{}' | CLAUDE_CONFIG_DIR="$TMP_DIR/no-such-config" sh -c "$frontmatter_command" >/dev/null 2>&1 || missing_guard_status=$?
[ "$missing_guard_status" -eq 2 ] || {
	printf 'read-only agent hook command must exit 2 when the guard script is missing, got %s\n' "$missing_guard_status" >&2
	exit 1
}

jq -e '[.hooks.PreToolUse[] | select(.matcher == "Write|Edit|MultiEdit") | .hooks[] | select(.command | contains("no-comments-guard.mjs"))] | length == 1' "$ROOT_DIR/claude/settings.workflow-hooks.json" >/dev/null || {
	printf 'settings.workflow-hooks.json must wire no-comments-guard on Write|Edit|MultiEdit\n' >&2
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
hung_rtk_dir="$TMP_DIR/hung-rtk"
mkdir -p "$hung_rtk_dir"
printf '#!/bin/sh\nexec sleep 8\n' >"$hung_rtk_dir/rtk"
chmod +x "$hung_rtk_dir/rtk"
hung_started="$("$node_bin" -p 'Date.now()')"
hung_status=0
hung_out="$(jq -nc '{tool_name:"Bash",tool_input:{command:"git status"}}' | PATH="$hung_rtk_dir:$PATH" "$node_bin" "$rtk_guard")" || hung_status=$?
hung_ms=$(($("$node_bin" -p 'Date.now()') - hung_started))
[ "$hung_status" -eq 0 ] && [ -z "$hung_out" ] && [ "$hung_ms" -lt 2500 ] || {
	printf 'rtk-guard must allow the raw command within 2.5 s when rtk hangs, got status %s after %s ms: %s\n' "$hung_status" "$hung_ms" "$hung_out" >&2
	exit 1
}
large_rtk_dir="$TMP_DIR/large-rtk"
mkdir -p "$large_rtk_dir"
printf '#!/bin/sh\nexec %s -e %s\n' "$node_bin" "'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:\"PreToolUse\",updatedInput:{command:\"rtk \" + \"x\".repeat(1000000)}}}))'" >"$large_rtk_dir/rtk"
chmod +x "$large_rtk_dir/rtk"
large_bytes="$(jq -nc '{tool_name:"Bash",tool_input:{command:"git status"}}' | PATH="$large_rtk_dir:$PATH" "$node_bin" "$rtk_guard" | wc -c | tr -d ' ')"
[ "$large_bytes" -gt 1000000 ] || {
	printf 'rtk-guard truncated a large rtk reply to %s bytes\n' "$large_bytes" >&2
	exit 1
}

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

hash_repo="$TMP_DIR/re#po"
mkdir -p "$hash_repo/scripts/lib" "$hash_repo/claude" "$TMP_DIR/hash-home/.claude"
cp "$ROOT_DIR/scripts/claude-hooks-merge" "$hash_repo/scripts/"
cp "$ROOT_DIR/scripts/lib/surfaces.mjs" "$ROOT_DIR/scripts/lib/claude-hooks-merge.mjs" "$ROOT_DIR/scripts/lib/claude-hooks-fragment.mjs" "$hash_repo/scripts/lib/"
cp "$ROOT_DIR/claude/settings.workflow-hooks.json" "$hash_repo/claude/"
"$hash_repo/scripts/claude-hooks-merge" --home "$TMP_DIR/hash-home" --dry-run >"$TMP_DIR/hash-merge.txt" 2>&1 || {
	printf 'claude-hooks-merge failed from a repo path containing #:\n%s\n' "$(cat "$TMP_DIR/hash-merge.txt")" >&2
	exit 1
}
assert_contains "$(cat "$TMP_DIR/hash-merge.txt")" 'would add'

for tool in claude-hooks-merge claude-hooks-check; do
	status=0
	"$ROOT_DIR/scripts/$tool" --home >/dev/null 2>"$TMP_DIR/home-last.txt" || status=$?
	[ "$status" -eq 2 ] || {
		printf '%s --home without a value exited %s, expected 2\n' "$tool" "$status" >&2
		exit 1
	}
	assert_contains "$(cat "$TMP_DIR/home-last.txt")" 'Usage:'
done

printf 'claude hooks smoke test: ok\n'
