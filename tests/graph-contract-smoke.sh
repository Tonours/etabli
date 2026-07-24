#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CONTRACT="$ROOT_DIR/workflow/skills/obvault-memory.md"

fail() {
  printf 'graph contract smoke: %s\n' "$1" >&2
  exit 1
}

[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

assert_contains() {
  local needle="$1"
  grep -Fq "$needle" "$CONTRACT" || fail "contract missing required invariant: $needle"
}

# Derived graph over Markdown-canonical (not a graph DB)
assert_contains "derived graph"
assert_contains "Markdown"
assert_contains "canonical"
assert_contains "wikilink"
assert_contains "untrusted"
assert_contains "JIT"
if ! grep -Eq '1–2 hop|1-2 hop|1 hop' "$CONTRACT"; then
  fail "contract missing 1–2 hop language"
fi

# Explicit hop / token bounds (1 hop default, max 2)
if ! grep -Eq 'hop' "$CONTRACT"; then
  fail "contract missing hop bound language"
fi
if ! grep -Eq 'max.?tokens|token cap|max.tokens' "$CONTRACT"; then
  # "token cap" is enough
  grep -Fq "token" "$CONTRACT" || fail "contract missing token budget language"
fi

# Point to existing kb notes (by basename, as durable vocabulary)
assert_contains "derived-graph-markdown-canonical"
assert_contains "graph-memory-over-token-dump"
assert_contains "compiled-wiki-vs-rag-complement"
assert_contains "adr-etabli-execution-vs-obvault-memory"

# Separation + write gates
assert_contains "capture"
assert_contains "distill --shadow"
assert_contains "never"

# Mechanical helper must exist for neighborhood packs
[ -x "$ROOT_DIR/scripts/graph-neighborhood" ] || fail "scripts/graph-neighborhood not executable"
[ -f "$ROOT_DIR/scripts/lib/graph-neighborhood.mjs" ] || fail "missing graph-neighborhood.mjs"

printf 'graph contract smoke test: ok\n'
