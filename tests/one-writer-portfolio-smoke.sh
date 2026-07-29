#!/usr/bin/env bash
# G2: portfolio sidecars are read-only tool pins (protocol/proxy, not OS lock).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
AGENTS_DIR="$ROOT_DIR/pi/agents"

fail() {
  printf 'one-writer-portfolio smoke: %s\n' "$1" >&2
  exit 1
}

count=0
for f in "$AGENTS_DIR"/etabli-*.md; do
  [ -f "$f" ] || fail "missing portfolio agents"
  tools_line="$(grep -E '^tools:' "$f" | head -1 || true)"
  [ -n "$tools_line" ] || fail "no tools: frontmatter in $f"
  # Must be exactly the read-only set (order-insensitive)
  tools="$(printf '%s\n' "$tools_line" | sed 's/^tools:[[:space:]]*//' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort | tr '\n' ',' | sed 's/,$//')"
  [ "$tools" = "find,grep,ls,read" ] || fail "expected find,grep,ls,read in $f got: $tools"
  printf '%s\n' "$tools_line" | grep -Eiq '(^|[, ])(bash|edit|write)([, ]|$)' &&
    fail "forbidden write/edit/bash tool in $f: $tools_line"
  count=$((count + 1))
done
[ "$count" -ge 5 ] || fail "expected >=5 etabli-* agents, got $count"

# Permanent proxy honesty: must not claim OS lock for one-writer
for doc in \
  "$ROOT_DIR/workflow/agent-quick-card.md" \
  "$ROOT_DIR/workflow/skills/multi-model-orchestration.md" \
  "$ROOT_DIR/workflow/runtime-capabilities.json"
do
  [ -f "$doc" ] || fail "missing $doc"
  if grep -Eiq 'one[- ]writer.*(os lock|kernel lock|file lock)|os lock.*one[- ]writer' "$doc"; then
    # allow explicit "not an OS lock" / "protocol/proxy not an OS lock"
    if ! grep -Eiq 'not an OS lock|protocol/proxy not an OS lock|protocol, not an OS lock' "$doc"; then
      fail "one-writer OS-lock claim without proxy honesty in $doc"
    fi
  fi
done

grep -Eq 'protocol.*not an OS lock|not an OS lock' "$ROOT_DIR/workflow/agent-quick-card.md" ||
  fail "quick card must state one-writer is protocol not OS lock"

printf 'one-writer-portfolio smoke test: ok\n'
