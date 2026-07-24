#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CLI="$ROOT_DIR/scripts/graph-neighborhood"
FIXTURE="$ROOT_DIR/tests/fixtures/graph-neighborhood"

fail() {
  printf 'graph neighborhood smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$CLI" ] || fail "graph-neighborhood not executable"
[ -d "$FIXTURE/kb" ] || fail "missing fixture vault"

# hops=1: seed alpha must include neighbor beta, not require gamma
hop1="$("$CLI" --vault "$FIXTURE" --hops 1 --seed-limit 1 --max-tokens 800 "seed-note-alpha graph engineering")"
printf '%s\n' "$hop1" | jq -e '.hops == 1' >/dev/null || fail "hops!=1"
printf '%s\n' "$hop1" | jq -e '.trust == "untrusted-retrieved-content"' >/dev/null || fail "trust label missing"
printf '%s\n' "$hop1" | jq -e '.canonical == "markdown-files"' >/dev/null || fail "canonical missing"
printf '%s\n' "$hop1" | jq -e '
  (.paths | map(test("seed-note-alpha|neighbor-note-beta")) | any)
  and (.neighbors | map(test("neighbor-note-beta")) | any)
' >/dev/null || fail "hop1 must include alpha seed neighborhood beta: $hop1"
printf '%s\n' "$hop1" | jq -e '
  (.paths | map(test("second-hop-gamma")) | any) | not
' >/dev/null || fail "hop1 must NOT include gamma: $hop1"

# hops=2: gamma included via beta
hop2="$("$CLI" --vault "$FIXTURE" --hops 2 --seed-limit 1 --max-tokens 800 "seed-note-alpha graph engineering")"
printf '%s\n' "$hop2" | jq -e '
  (.paths | map(test("second-hop-gamma")) | any)
  and (.hops == 2)
' >/dev/null || fail "hop2 must include gamma: $hop2"

# Stale path must be labeled when lexically selected
stale="$("$CLI" --vault "$FIXTURE" --hops 1 --max-tokens 800 "stale wrong path graph engineering")"
printf '%s\n' "$stale" | jq -e '
  (.stale_paths | length) >= 1
  or (.excerpts | map(select(.status_stale == true)) | length) >= 1
' >/dev/null || fail "stale note must be labeled: $stale"

# Token cap must not be exceeded
printf '%s\n' "$hop1" | jq -e '.estimated_tokens <= .max_tokens' >/dev/null || fail "token cap exceeded"

# Expand-2 evidence: multi-hop (gamma) requires hops=2; default pack stays 1 for MVC
# (recorded by suite caller; here we prove the differential)
printf 'graph neighborhood smoke test: ok\n'
