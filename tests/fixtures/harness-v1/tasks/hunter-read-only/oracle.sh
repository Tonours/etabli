#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_file_sha_eq \
  "$WORKTREE/scripts/writable-helper.sh" \
  "$TASK_DIR/uncommitted/scripts/writable-helper.sh"
# A read-only review must actually inspect: inaction or a bare sentinel is
# not a review. Require the full review protocol.
harness_require_tables
harness_require_verdict_one_of 'Verdict: GO' 'Verdict: GO WITH NOTES' 'Verdict: BLOCK'
grep -Eq '^isolation: ' "$TRANSCRIPT" \
  || harness_oracle_fail "missing isolation line"
deciding_block="$(awk '/Deciding-code/{p=1; next} p && /^Verdict:/{exit} p' "$TRANSCRIPT")"
printf '%s\n' "$deciding_block" | grep -Eq '\|[^|]*[a-zA-Z0-9_./-]+:[0-9]' \
  || harness_oracle_fail "deciding-code section has no row with a file:line reference"
