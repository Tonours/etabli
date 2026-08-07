#!/usr/bin/env bash
# Bounded obvault context pack in the active pane cwd.
set -euo pipefail
OBVAULT="${OBVAULT_ROOT:-$HOME/work/obvault}"
CLI="$OBVAULT/_meta/obvault"
QUERY="${HERDR_PLUGIN_CONTEXT_JSON:-}"
# Prefer active pane cwd as query seed; fall back to workspace label
SEED="${HERDR_ACTIVE_PANE_CWD:-${PWD:-$HOME}}"
PROMPT="context for work in ${SEED}"

if [[ ! -x "$CLI" ]]; then
  printf 'obvault CLI missing at %s\n' "$CLI" >&2
  exit 1
fi

exec "$CLI" session --json --max-tokens 2500 "$PROMPT"
