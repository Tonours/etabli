#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${RUN_LIVE_OBVAULT_SMOKE:-0}" = "1" ]; then
  OBVAULT="${OBVAULT_ROOT:-$HOME/work/obvault}"
else
  OBVAULT="$TMP_DIR/obvault"
  mkdir -p "$OBVAULT/kb" "$OBVAULT/ref"
  printf '# Test vault\n' > "$OBVAULT/AGENTS.md"
  printf '# Second Brain Architecture\n' > "$OBVAULT/kb/llm-wiki-second-brain-architecture.md"
  ln -s "$ROOT_DIR/tests/fixtures/obvault-meta" "$OBVAULT/_meta"
fi

export OBVAULT_ROOT="$OBVAULT"
CLI="$OBVAULT/_meta/obvault"

test -x "$CLI"
"$CLI" validate --mode strict >/dev/null
result="$($CLI query --json 'second brain architecture')"
printf '%s' "$result" | jq -e 'length > 0 and .[0].path == "kb/llm-wiki-second-brain-architecture.md"' >/dev/null
pack="$($CLI context --json --max-tokens 250 'second brain architecture')"
printf '%s' "$pack" | jq -e '.estimated_tokens <= 250 and (.results | length) > 0' >/dev/null
printf 'obvault query smoke test: ok\n'
