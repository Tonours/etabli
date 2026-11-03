#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
	printf 'prs-today smoke: %s\n' "$1" >&2
	exit 1
}

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/views"
cat >"$TMP_DIR/bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "$1 $2" = "search prs" ]; then
	cat "$GH_FIXTURES/search.json"
	exit 0
fi
if [ "$1 $2" = "pr view" ]; then
	file="$GH_FIXTURES/views/${5//\//_}_$3.json"
	if [ -f "$file" ]; then cat "$file"; exit 0; fi
	[ -n "${GH_DEFAULT_VIEW:-}" ] && { cat "$GH_DEFAULT_VIEW"; exit 0; }
	printf 'GraphQL: Could not resolve to a PullRequest with the number of %s.\n' "$3" >&2
	exit 1
fi
exit 2
SH
chmod +x "$TMP_DIR/bin/gh"
export PATH="$TMP_DIR/bin:$PATH" GH_FIXTURES="$TMP_DIR"

TMP_DIR="$TMP_DIR" node --input-type=module <<'NODE'
import { writeFileSync } from "node:fs";
const dir = process.env.TMP_DIR;
const search = [];
const view = (repo, number, extra) => {
	search.push({ number, repository: { nameWithOwner: repo }, url: `https://github.com/${repo}/pull/${number}` });
	if (extra === null) return;
	writeFileSync(`${dir}/views/${repo.replace("/", "_")}_${number}.json`, JSON.stringify({
		state: "OPEN", reviewDecision: "", statusCheckRollup: [], baseRefName: "main", headRefName: `b${number}`,
		headRepository: { nameWithOwner: repo }, mergeable: "MERGEABLE", url: `https://github.com/${repo}/pull/${number}`, ...extra,
	}));
};
const ok = { __typename: "CheckRun", status: "COMPLETED", conclusion: "SUCCESS" };
view("acme/app", 30, { baseRefName: "b20", headRefName: "b30", statusCheckRollup: [ok, { __typename: "CheckRun", status: "IN_PROGRESS", conclusion: "" }] });
view("acme/app", 10, { headRefName: "b10", reviewDecision: "APPROVED", statusCheckRollup: [ok] });
view("acme/app", 20, { baseRefName: "b10", headRefName: "b20", mergeable: "UNKNOWN", statusCheckRollup: [ok, { __typename: "StatusContext", state: "FAILURE" }] });
view("acme/app", 40, { headRefName: "b40", headRepository: { nameWithOwner: "fork/app" } });
view("acme/app", 50, { headRefName: "b10", headRepository: { nameWithOwner: "fork/app" } });
view("acme/app", 60, { baseRefName: "gone", headRefName: "b60" });
view("acme/app", 70, { state: "MERGED" });
view("acme/app", 80, null);
view("acme/cyc", 1, { baseRefName: "b2", headRefName: "b1" });
view("acme/cyc", 2, { baseRefName: "b1", headRefName: "b2" });
view("acme/amb", 5, { baseRefName: "x", headRefName: "b5" });
view("acme/amb", 6, { headRefName: "x" });
view("acme/amb", 7, { headRefName: "x" });
writeFileSync(`${dir}/search.json`, JSON.stringify(search));
NODE

status=0
out=$("$ROOT_DIR/scripts/prs-today" 2>"$TMP_DIR/err") || status=$?
[ "$status" -eq 0 ] || fail "exit $status: $(cat "$TMP_DIR/err")"
[ ! -s "$TMP_DIR/err" ] || fail "no warning expected under 100 PRs: $(cat "$TMP_DIR/err")"
app=$(printf '%s\n' "$out" | sed -n '/^acme\/app$/,/^acme\/[a-z]*$/p' | grep '^  #' | sed -E 's/^  #([0-9]+).*/\1/' | tr '\n' ' ')
[ "$app" = "10 20 30 40 50 60 70 80 " ] || fail "acme/app order should be 10 20 30 40 50 60 70 80, got '$app' in: $out"
line() {
	printf '%s\n' "$out" | grep -E "^  #$1( |$)" || fail "missing row #$1 in: $out"
}
line 10 | grep -q "review=APPROVED ci=pass base=main mergeable=MERGEABLE" || fail "row 10: $(line 10)"
line 20 | grep -q "after #10 .*ci=fail .*mergeable=UNKNOWN" || fail "row 20: $(line 20)"
line 30 | grep -q "after #20 .*ci=pending" || fail "row 30: $(line 30)"
line 40 | grep -q "ci=none" || fail "row 40: $(line 40)"
! printf '%s\n' "$out" | grep -q "after #50" || fail "a fork with a same-name branch is not a parent: $out"
! line 60 | grep -q "after" || fail "a missing parent leaves no order: $(line 60)"
line 70 | grep -q "merged since the search" || fail "row 70: $(line 70)"
line 80 | grep -q "view failed: GraphQL" || fail "row 80: $(line 80)"
for repo in cyc amb; do
	printf '%s\n' "$out" | sed -n "/^acme\/$repo$/,/^acme/p" | grep -q "stack: ambiguous" || fail "acme/$repo must print stack: ambiguous: $out"
done

TMP_DIR="$TMP_DIR" node -e '
const fs = require("node:fs");
const dir = process.env.TMP_DIR;
fs.writeFileSync(`${dir}/search.json`, JSON.stringify(Array.from({ length: 100 }, (_, i) => ({ number: i + 1, repository: { nameWithOwner: "acme/many" }, url: "u" }))));
fs.writeFileSync(`${dir}/default.json`, JSON.stringify({ state: "OPEN", reviewDecision: "", statusCheckRollup: [], baseRefName: "main", headRefName: "h", headRepository: { nameWithOwner: "x/y" }, mergeable: "MERGEABLE", url: "u" }));
'
GH_DEFAULT_VIEW="$TMP_DIR/default.json" "$ROOT_DIR/scripts/prs-today" >/dev/null 2>"$TMP_DIR/err" || fail "truncated run failed"
grep -q "may be truncated" "$TMP_DIR/err" || fail "100 results must warn about truncation"

printf 'prs-today smoke test: ok\n'
