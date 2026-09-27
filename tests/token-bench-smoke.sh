#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
BENCH="$ROOT_DIR/scripts/token-bench"
FIXTURES="$ROOT_DIR/tests/fixtures/token-bench"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
	printf 'token-bench smoke: %s\n' "$1" >&2
	exit 1
}

expect_exit() {
	local want="$1" message="$2"
	shift 2
	set +e
	"$@" >"$TMP_DIR/out" 2>"$TMP_DIR/err"
	local got=$?
	set -e
	[ "$got" -eq "$want" ] || fail "$message: want exit $want, got $got ($(cat "$TMP_DIR/err"))"
}

TREE="$TMP_DIR/tree"
cp -R "$FIXTURES/tree" "$TREE"
for file in a b c; do printf '%0100d' 0 >"$TREE/$file.md"; done

json="$("$BENCH" --root "$TREE" --json)"
[ "$(jq -r '.offline.surfaces["always-on"].chars' <<<"$json")" = "100" ] || fail "always-on surface must sum its files"
[ "$(jq -r '.offline.routes.implement.chars' <<<"$json")" = "200" ] || fail "route cost must be always-on plus the route chain"
[ "$(jq -r '.offline.routes.implement.worst_chars' <<<"$json")" = "300" ] || fail "worst case must add conditional reads"
[ "$(jq -r '.offline.routes.implement.est_tokens' <<<"$json")" = "50" ] || fail "est_tokens must be ceil(chars/4)"
[ "$(jq -r '.offline.routes | keys | join(",")' <<<"$json")" = "implement" ] || fail "always-on and spec-map are surfaces, not routes"
[ "$(jq -r '.offline.surfaces | has("spec-map")' <<<"$json")" = "true" ] || fail "spec-map stays a measured surface"
[ "$(jq -r 'has("comparison")' <<<"$json")" = "false" ] || fail "no baseline means no comparison"

expect_exit 2 "--check without a baseline" "$BENCH" --root "$TREE" --check
grep -Fq -- '--write-baseline' "$TMP_DIR/err" || fail "missing-baseline error must name --write-baseline"

"$BENCH" --root "$TREE" --write-baseline >/dev/null
BASELINE="$TREE/workflow/runtime/token-bench-baseline.json"
[ -f "$BASELINE" ] || fail "--write-baseline must write the default baseline"
"$BENCH" --root "$TREE" --check >/dev/null || fail "unchanged tree must pass --check"

printf 'xxx' >>"$TREE/b.md"
"$BENCH" --root "$TREE" --check >/dev/null || fail "growth of exactly the tolerance (3%) must pass"
printf 'x' >>"$TREE/b.md"
expect_exit 1 "growth over the tolerance" "$BENCH" --root "$TREE" --check
grep -Fq 'surfaces.implement.chars grew 4%' "$TMP_DIR/err" || fail "regression must name the value and its growth"
grep -Fq 'scripts/token-bench --write-baseline' "$TMP_DIR/err" || fail "regression must name its remediation"
"$BENCH" --root "$TREE" --check --tolerance 4 >/dev/null || fail "--tolerance must widen the bound"
expect_exit 2 "a non-numeric tolerance" "$BENCH" --root "$TREE" --check --tolerance abc
expect_exit 2 "a flag taken as an option value" "$BENCH" --root "$TREE" --baseline --check
expect_exit 2 "an empty option value" "$BENCH" --root "$TREE" --check --context-json ""

WIDE="$TMP_DIR/wide"
cp -R "$FIXTURES/tree" "$WIDE"
for file in a b c; do printf '%010000d' 0 >"$WIDE/$file.md"; done
"$BENCH" --root "$WIDE" --write-baseline >/dev/null
printf '%07d' 0 >>"$WIDE/a.md"
"$BENCH" --root "$WIDE" --check --tolerance 0.07 >/dev/null || fail "growth of exactly a decimal tolerance must pass"
printf 'x' >>"$WIDE/a.md"
expect_exit 1 "growth just over a decimal tolerance" "$BENCH" --root "$WIDE" --check --tolerance 0.07

cp "$BASELINE" "$TMP_DIR/baseline.json"
jq '.schema_version = 2' "$TMP_DIR/baseline.json" >"$BASELINE"
expect_exit 2 "an unknown baseline schema" "$BENCH" --root "$TREE" --check
jq '.surfaces["always-on"].chars = 0' "$TMP_DIR/baseline.json" >"$BASELINE"
expect_exit 2 "a zero baseline value" "$BENCH" --root "$TREE" --check
jq 'del(.surfaces["spec-map"])' "$TMP_DIR/baseline.json" >"$BASELINE"
expect_exit 2 "a surface missing from the baseline" "$BENCH" --root "$TREE" --check
grep -Fq 'added: surfaces.spec-map.chars' "$TMP_DIR/err" || fail "an incomplete comparison must name the added value"
cp "$TMP_DIR/baseline.json" "$BASELINE"

BUDGET="$TREE/workflow/runtime/context-budget.json"
cp "$BUDGET" "$TMP_DIR/budget.json"
jq '.surfaces.implement.ceiling_chars = 1' "$TMP_DIR/budget.json" >"$BUDGET"
"$BENCH" --root "$TREE" --json >/dev/null || fail "an over-ceiling surface must still be measured"
jq '.surfaces.implement.conditional += [{"file": "gone.md", "trigger": "fixture"}]' "$TMP_DIR/budget.json" >"$BUDGET"
expect_exit 2 "a missing conditional file" "$BENCH" --root "$TREE"
grep -Fq 'not a readable file (gone.md)' "$TMP_DIR/err" || fail "a missing conditional file must be named"
jq '.surfaces.implement.conditional = [{"file": "workflow"}]' "$TMP_DIR/budget.json" >"$BUDGET"
expect_exit 2 "a directory as conditional file" "$BENCH" --root "$TREE"
for conditional in 'null' '{}' '[{}]'; do
	jq --argjson c "$conditional" '.surfaces.implement.conditional = $c' "$TMP_DIR/budget.json" >"$BUDGET"
	expect_exit 2 "a malformed conditional ($conditional)" "$BENCH" --root "$TREE"
	grep -Fq 'conditional must be an array' "$TMP_DIR/err" || fail "a malformed conditional must be named"
done
cp "$TMP_DIR/budget.json" "$BUDGET"
mv "$TREE/c.md" "$TMP_DIR/c.md"
expect_exit 2 "a missing budget file" "$BENCH" --root "$TREE"
grep -Fq 'missing files (spec-map: c.md)' "$TMP_DIR/err" || fail "a missing file must be named, never measured as a saving"
mv "$TMP_DIR/c.md" "$TREE/c.md"

live="$("$BENCH" --root "$TREE" --context-json "$FIXTURES/context-free.json" --json)"
[ "$(jq -r '.live.categories.Skills' <<<"$live")" = "9000" ] || fail "live must parse 9k"
[ "$(jq -r '.live.categories["System prompt"]' <<<"$live")" = "1400" ] || fail "live must parse 1.4k"
[ "$(jq -r '.live.categories["MCP tools"]' <<<"$live")" = "634" ] || fail "live must parse plain counts"
[ "$(jq -r '.live.total_tokens' <<<"$live")" = "16500" ] || fail "live must parse the total"
[ "$(jq -r '.live.model' <<<"$live")" = "claude-opus-5-5" ] || fail "live must record the displayed model"
[ "$(jq -r '.live.categories | has("x")' <<<"$live")" = "false" ] || fail "live must stop at the category table"
for cell in '9,000:9000' '1..4k:' 'abc:' '-:' '---:'; do
	value="${cell%%:*}"
	want="${cell#*:}"
	jq --arg v "$value" '.result |= sub("\\| Skills \\| 9k \\|"; "| Skills | \($v) |")' "$FIXTURES/context-free.json" >"$TMP_DIR/context-cell.json"
	if [ -n "$want" ]; then
		[ "$("$BENCH" --root "$TREE" --context-json "$TMP_DIR/context-cell.json" --json | jq -r '.live.categories.Skills')" = "$want" ] ||
			fail "live must parse a thousands separator ($value)"
	else
		expect_exit 2 "an unparseable token cell ($value)" "$BENCH" --root "$TREE" --context-json "$TMP_DIR/context-cell.json"
		grep -Fq 'unparseable token count' "$TMP_DIR/err" || fail "an unparseable token cell must be named ($value)"
	fi
done
jq '.result |= sub("\\|----------\\|--------\\|------------\\|"; "|:---------|-------:|-----------:|")' "$FIXTURES/context-free.json" >"$TMP_DIR/context-aligned.json"
grep -Fq ':---------|' "$TMP_DIR/context-aligned.json" || fail "aligned separator fixture was not built"
[ "$("$BENCH" --root "$TREE" --context-json "$TMP_DIR/context-aligned.json" --json | jq -r '.live.categories.Skills')" = "9000" ] ||
	fail "an aligned markdown separator row must be skipped"

for case in paid:'total_cost_usd 0, got 0.01' nocost:'total_cost_usd 0, got undefined' broken:"no 'Estimated usage by category' table"; do
	name="${case%%:*}"
	expect_exit 2 "$name /context sample" "$BENCH" --root "$TREE" --context-json "$FIXTURES/context-$name.json"
	grep -Fq "${case#*:}" "$TMP_DIR/err" || fail "$name refusal must say: ${case#*:}"
done

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >>"$FAKE_CLAUDE_LOG"
[ "$1" = "--version" ] && { printf '9.9.9 (Claude Code)\n'; exit 0; }
cat "$FAKE_CLAUDE_OUTPUT"
exit "${FAKE_CLAUDE_EXIT:-0}"
EOF
chmod +x "$TMP_DIR/bin/claude"
export FAKE_CLAUDE_LOG="$TMP_DIR/claude.log" FAKE_CLAUDE_OUTPUT="$FIXTURES/context-free.json"
live="$(PATH="$TMP_DIR/bin:$PATH" "$BENCH" --root "$TREE" --live --json)"
[ "$(jq -r '.live.claude_version' <<<"$live")" = "9.9.9 (Claude Code)" ] || fail "live must record claude --version"
grep -Fxq "$(cd "$TREE" && pwd -P)|-p /context --output-format json" "$FAKE_CLAUDE_LOG" ||
	grep -Fxq "$TREE|-p /context --output-format json" "$FAKE_CLAUDE_LOG" || fail "live must run /context in --root with the pinned arguments"
expect_exit 2 "a failing claude process" env FAKE_CLAUDE_EXIT=1 PATH="$TMP_DIR/bin:$PATH" "$BENCH" --root "$TREE" --live
expect_exit 2 "a paid live sample" env FAKE_CLAUDE_OUTPUT="$FIXTURES/context-paid.json" PATH="$TMP_DIR/bin:$PATH" "$BENCH" --root "$TREE" --live

SKILLS="$TMP_DIR/skills"
cp -R "$FIXTURES/skills" "$SKILLS"
ln -s ../../claude/scopes/shared/skills/quoted-skill "$SKILLS/pi/skills/alias-skill"
ln -s .. "$SKILLS/pi/skills/good-skill/loop"
ln -s good-skill "$SKILLS/pi/skills/z-alias"
for _ in $(seq 100); do printf 'line\n'; done >"$SKILLS/pi/skills/good-skill/exact-100.md"
for _ in $(seq 120); do printf 'line\n'; done >>"$SKILLS/pi/skills/good-skill/reference.md"
skills="$("$BENCH" --skills --root "$SKILLS" --json)"
skill() { jq -r ".skills[] | select(.name == \"$1\") | $2" <<<"$skills"; }
[ "$(jq -r '.totals.skills' <<<"$skills")" = "3" ] || fail "--skills must count a symlinked skill once"
[ "$(skill quoted-skill '.aliases | join(",")')" = "pi/skills/alias-skill" ] || fail "--skills must list symlink aliases"
[ "$(skill good-skill '.aliases | join(",")')" = "pi/skills/z-alias" ] || fail "an alias visited after its target must still be listed"
[ "$(skill good-skill '.description_chars')" = "109" ] || fail "a folded block description must decode from the frontmatter only"
[ "$(skill good-skill '.hard | length')" = "0" ] || fail "a GENERATED body copy must not count as the description"
[ "$(skill quoted-skill '.description_chars')" = "85" ] || fail "a double-quoted description must decode its escapes"
[ "$(skill quoted-skill '.listing_chars')" = "101" ] || fail "listing must add a single-quoted when_to_use"
skill good-skill '.warnings[]' | grep -Fq 'reference.md has > 100 lines and no contents heading' ||
	fail "a long reference without contents must warn"
if skill good-skill '.warnings[]' | grep -Fq 'exact-100.md'; then fail "a 100-line reference is within the limit"; fi
[ "$(jq -r '.totals.upstream_hard_violations' <<<"$skills")" = "1" ] || fail "upstream violations must be reported"
"$BENCH" --skills --root "$SKILLS" --check >/dev/null || fail "upstream violations must not gate"

write_skill() {
	local name="$1" description="$2" body_lines="$3"
	mkdir -p "$SKILLS/extras/skills/$name"
	{
		printf -- '---\nname: %s\ndescription: %s\n---\n' "$name" "$description"
		for _ in $(seq "$body_lines"); do printf 'body\n'; done
	} >"$SKILLS/extras/skills/$name/SKILL.md"
}
write_raw_skill() {
	mkdir -p "$SKILLS/extras/skills/$1"
	printf -- '---\nname: %s\n%s\n---\nbody\n' "$1" "$2" >"$SKILLS/extras/skills/$1/SKILL.md"
}
write_raw_skill yaml-hex 'description: "\x3cb\x3e"'
write_raw_skill yaml-comment 'description: "" # empty'
write_raw_skill yaml-plain-comment 'description: # nothing here'
write_raw_skill yaml-strip "$(printf 'description: >-\n  %s' "$(printf 'd%.0s' $(seq 1024))")"
write_raw_skill yaml-clip "$(printf 'description: >\n  %s' "$(printf 'd%.0s' $(seq 1024))")"
skills="$("$BENCH" --skills --root "$SKILLS" --json)"
write_raw_skill yaml-multiline "$(printf 'description: "hello\n  <b>world</b>"')"
write_raw_skill yaml-escaped-break "$(printf 'description: "<\\\n  b>"')"
write_raw_skill yaml-invalid 'description: [unclosed'
write_raw_skill yaml-mapping 'description: {foo: "<b>"}'
write_raw_skill yaml-tostring 'description: {toString: foo}'
write_raw_skill yaml-dmi "$(printf 'description: Manual only. Use by explicit invocation.\ndisable-model-invocation: true')"
write_raw_skill yaml-indent "$(printf 'description: |2-\n    %s' "$(printf 'd%.0s' $(seq 1023))")"
skills="$("$BENCH" --skills --root "$SKILLS" --json)"
skill yaml-multiline '.hard[]' | grep -Fq 'XML tag' || fail "a multi-line quoted description must be decoded whole"
[ "$(skill yaml-multiline '.description_chars')" = "18" ] || fail "a multi-line quoted scalar folds its line break to a space"
[ "$(skill yaml-indent '.description_chars')" = "1025" ] || fail "an explicit indentation indicator keeps the extra indentation"
skill yaml-escaped-break '.hard[]' | grep -Fq 'XML tag' || fail "an escaped line break joins the lines without a space"
skill yaml-invalid '.hard[]' | grep -Fq 'frontmatter is not valid YAML' || fail "invalid YAML must be a hard violation"
for key in yaml-mapping yaml-tostring; do
	skill "$key" '.hard[]' | grep -Fq 'description must be a string, got object' || fail "$key: a non-string description must be a hard violation"
done
[ "$(skill yaml-dmi '.model_invocable')" = "false" ] || fail "disable-model-invocation: true keeps a skill out of the model listing"
skill yaml-hex '.hard[]' | grep -Fq 'XML tag' || fail "an escaped tag must decode before the XML check"
skill yaml-comment '.hard[]' | grep -Fq 'description is empty' || fail "a trailing comment is not part of the description"
skill yaml-plain-comment '.hard[]' | grep -Fq 'description is empty' || fail "a plain-scalar comment is not part of the description"
[ "$(skill yaml-strip '.description_chars')" = "1024" ] || fail ">- must strip the final newline"
[ "$(skill yaml-clip '.description_chars')" = "1025" ] || fail "> must keep one final newline"
rm -rf "$SKILLS"/extras/skills/yaml-*

DEPTH="$SKILLS/extras/skills/depth"
mkdir -p "$DEPTH"
printf -- '---\nname: depth\ndescription: Depth fixture. Use in the smoke only.\n---\nSee beta.md, a.md.backup and index.md.\n' >"$DEPTH/SKILL.md"
printf 'beta\n' >"$DEPTH/beta.md"
printf 'See a.md.\n' >"$DEPTH/index.md"
printf 'a\n' >"$DEPTH/a.md"
skills="$("$BENCH" --skills --root "$SKILLS" --json)"
skill depth '.warnings[]' | grep -Fq '1 reference(s) reachable only through another reference, e.g. a.md' ||
	fail "a basename that is a suffix of another link must not count as linked"
printf -- '---\nname: depth\ndescription: Depth fixture. Use in the smoke only.\n---\nRead [the index](./index.md).\n' >"$DEPTH/SKILL.md"
printf 'Read [leaf](./leaf.md).\n' >"$DEPTH/index.md"
printf 'leaf\n' >"$DEPTH/leaf.md"
rm -f "$DEPTH/beta.md" "$DEPTH/a.md"
skills="$("$BENCH" --skills --root "$SKILLS" --json)"
skill depth '.warnings[]' | grep -Fq '1 reference(s) reachable only through another reference, e.g. leaf.md' ||
	fail "./-prefixed markdown links must count as links"
rm -rf "$DEPTH"

write_skill edge-ok "$(printf 'd%.0s' $(seq 1024))" 499
"$BENCH" --skills --root "$SKILLS" --check >/dev/null || fail "a 1024-char description and a 499-line body are within the limits"
write_skill edge-over "$(printf 'd%.0s' $(seq 1025))" 500
write_skill Claude_Bad '<b>bold</b>' 1
expect_exit 1 "owned skills with hard violations" "$BENCH" --skills --root "$SKILLS" --check
skills="$("$BENCH" --skills --root "$SKILLS" --json)"
for rule in 'spec: description is 1025 chars' 'etabli-policy: body is 500 lines'; do
	skill edge-over '.hard[]' | grep -Fq "$rule" || fail "edge-over must report: $rule"
done
for rule in 'spec: name "Claude_Bad" must be <= 64 chars' 'spec: name "Claude_Bad" uses a reserved word' 'spec: description contains an XML tag'; do
	skill Claude_Bad '.hard[]' | grep -Fq "$rule" || fail "Claude_Bad must report: $rule"
done

printf 'token-bench smoke: ok\n'
