#!/usr/bin/env bash
# Action `check`: scan every claude agent once, report, fire nothing.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
with_lock scan_all
echo
echo "pending relaunches:"
read_entries | while IFS= read -r line; do
  due="$(entry_field "$line" 1)"; pane="$(entry_field "$line" 2)"
  cwd="$(entry_field "$line" 5)"; note="$(entry_field "$line" 7)"
  echo "  $pane  due $(date -r "$due" '+%H:%M' 2>/dev/null || date -d "@$due" '+%H:%M')  ${cwd##*/}  ($note)"
done
