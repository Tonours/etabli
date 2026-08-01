#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/claim-evidence-check"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
chmod +x "$CHECK"
cd "$ROOT_DIR"

"$CHECK" "$ROOT_DIR/tests/fixtures/claim-evidence/good.md" >"$TMP/ce-good.txt"
grep -Eq 'ok=true' "$TMP/ce-good.txt"

set +e
"$CHECK" --json "$ROOT_DIR/tests/fixtures/claim-evidence/bad.md" >"$TMP/ce-bad.json" 2>"$TMP/ce-bad.err"
st=$?
set -e
[ "$st" -ne 0 ] || {
	echo 'bad fixture should fail'
	exit 1
}
jq -e '.ok == false and .failed >= 1 and .graph.derived == true' "$TMP/ce-bad.json" >/dev/null

printf 'claim-evidence-check smoke test: ok\n'
