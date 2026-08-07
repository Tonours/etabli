#!/usr/bin/env bash
set -euo pipefail
OBVAULT="${OBVAULT_ROOT:-$HOME/work/obvault}"
CLI="$OBVAULT/_meta/obvault"
if [[ ! -x "$CLI" ]]; then
  printf 'obvault CLI missing at %s\n' "$CLI" >&2
  exit 1
fi
"$CLI" status --json
echo
"$CLI" loop --json 2>/dev/null || true
