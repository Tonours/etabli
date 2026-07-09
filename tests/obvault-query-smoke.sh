#!/usr/bin/env bash
set -euo pipefail
OBVAULT="${OBVAULT_ROOT:-$HOME/work/obvault}"
CLI="$OBVAULT/_meta/obvault"

test -x "$CLI"
"$CLI" validate --mode strict >/dev/null
result="$($CLI query --json 'second brain architecture')"
printf '%s' "$result" | jq -e 'length > 0 and .[0].path == "kb/llm-wiki-second-brain-architecture.md"' >/dev/null
pack="$($CLI context --json --max-tokens 250 'second brain architecture')"
printf '%s' "$pack" | jq -e '.estimated_tokens <= 250 and (.results | length) > 0' >/dev/null
printf 'obvault query smoke test: ok\n'
