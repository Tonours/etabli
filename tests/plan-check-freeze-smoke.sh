#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CLI="$ROOT_DIR/scripts/plan-check-freeze"
FIX="$ROOT_DIR/tests/fixtures/plan-check-freeze"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'plan-check-freeze smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$CLI" ] || fail "CLI not executable"

# Strengthen-only: add a check while READY → pass
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/ready-strengthened.md" >"$TMP/ok.json" 2>"$TMP/ok.err"
ok_status=$?
set -e
[ "$ok_status" -eq 0 ] || fail "strengthen-only should pass: $(cat "$TMP/ok.err" "$TMP/ok.json")"
jq -e '.ok == true' "$TMP/ok.json" >/dev/null

# Weaken READY without CHALLENGED → fail
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/ready-weakened.md" >"$TMP/bad.json" 2>"$TMP/bad.err"
bad_status=$?
set -e
[ "$bad_status" -ne 0 ] || fail "weaken READY should fail"
jq -e '.ok == false and (.removed | length) >= 1' "$TMP/bad.json" >/dev/null ||
  fail "expected removed checks: $(cat "$TMP/bad.json")"

# Weaken after CHALLENGED + Decision Log rationale → pass
set +e
"$CLI" --previous "$FIX/ready-baseline.md" --current "$FIX/challenged-weaken-ok.md" >"$TMP/ch.json" 2>"$TMP/ch.err"
ch_status=$?
set -e
[ "$ch_status" -eq 0 ] || fail "challenged weaken with rationale should pass: $(cat "$TMP/ch.json")"

# Acceptance Criteria are frozen the same way as Checks
set +e
"$CLI" --previous "$FIX/ready-with-ac-baseline.md" --current "$FIX/ready-ac-weakened.md" >"$TMP/ac-bad.json" 2>"$TMP/ac-bad.err"
ac_bad=$?
set -e
[ "$ac_bad" -ne 0 ] || fail "Acceptance Criteria weaken READY should fail"
jq -e '.ok == false and (.removed | length) >= 1' "$TMP/ac-bad.json" >/dev/null ||
  fail "expected removed acceptance criteria: $(cat "$TMP/ac-bad.json")"

set +e
"$CLI" --previous "$FIX/ready-with-ac-baseline.md" --current "$FIX/ready-ac-strengthened.md" >"$TMP/ac-ok.json" 2>"$TMP/ac-ok.err"
ac_ok=$?
set -e
[ "$ac_ok" -eq 0 ] || fail "Acceptance Criteria strengthen should pass: $(cat "$TMP/ac-ok.json")"
jq -e '.ok == true' "$TMP/ac-ok.json" >/dev/null

printf 'plan-check-freeze smoke test: ok\n'
