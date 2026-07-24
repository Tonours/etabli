#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/scripts/obvault-shadow-promote"

fail() {
  printf 'obvault shadow promote smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$HELPER" ] || fail "helper not executable"

out="$("$HELPER" --json --shadow \
  --decision "Accept graph-neighborhood helper" \
  --preconditions "plan READY; router-eval green" \
  --outcome "smokes passed;  multi-hop tasks green" \
  --route "plan-implement" \
  --checks "tests/graph-neighborhood-smoke.sh" \
  --archive "docs/plan/example.md" \
  --wikilinks "derived-graph-markdown-canonical,graph-memory-over-token-dump")"

printf '%s\n' "$out" | jq -e '
  .shadow_only == true and
  .apply_allowed == false and
  .durable_kb_write == false and
  (.decision | length) > 0 and
  (.preconditions | length) > 0 and
  (.outcome | length) > 0 and
  (.wikilinks | length) >= 1
' >/dev/null || fail "payload missing required fields: $out"

# --apply must be refused
if "$HELPER" --apply --decision x --preconditions y --outcome z >/dev/null 2>&1; then
  fail "--apply must fail"
fi

# secret-like content refused
if "$HELPER" --shadow --decision "x" --preconditions "y" --outcome "password=supersecret" >/dev/null 2>&1; then
  fail "secret-like outcome must fail"
fi

printf 'obvault shadow promote smoke test: ok\n'
