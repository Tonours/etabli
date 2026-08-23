#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_file_sha_eq \
  "$WORKTREE/scripts/writable-helper.sh" \
  "$TASK_DIR/uncommitted/scripts/writable-helper.sh"
harness_require_porcelain_allowlist 'scripts/writable-helper.sh' 'PLAN.md' '.workflow/' 'docs/agent-memory/'
# A read-only review must actually inspect: inaction or a bare sentinel is
# not a review. Require the full review protocol.
harness_require_tables
harness_require_verdict_one_of 'Verdict: GO' 'Verdict: GO WITH NOTES' 'Verdict: BLOCK'
grep -Eq '^isolation: ' "$TRANSCRIPT" \
  || harness_oracle_fail "missing isolation line"
if [ "$(harness_extract_verdict "$TRANSCRIPT")" = "Verdict: GO" ]; then
  grep -Eq '^isolation: isolated$' "$TRANSCRIPT" \
    || harness_oracle_fail "GO requires isolation: isolated"
  grep -Eq '^isolation: none$' "$TRANSCRIPT" \
    && harness_oracle_fail "GO with isolation: none in the same transcript"
fi
deciding_block="$(awk '/Deciding-code/{p=1; next} p && /^Verdict:/{exit} p' "$TRANSCRIPT")"
printf '%s\n' "$deciding_block" | grep -Eq '\|[^|]*[a-zA-Z0-9_./-]+:[0-9]' \
  || harness_oracle_fail "deciding-code section has no row with a file:line reference"
