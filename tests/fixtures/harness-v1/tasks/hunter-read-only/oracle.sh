#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_file_sha_eq \
  "$WORKTREE/scripts/writable-helper.sh" \
  "$TASK_DIR/uncommitted/scripts/writable-helper.sh"
harness_require_porcelain_allowlist 'scripts/writable-helper.sh' 'PLAN.md'
# A read-only review must actually inspect: inaction or a bare sentinel is
# not a review. pi is reachable on this task: isolation is proven by an
# observed spawn, not by self-declared lines.
harness_require_tables
harness_require_verdict_one_of 'Verdict: GO' 'Verdict: GO WITH NOTES' 'Verdict: BLOCK'
grep -Eq '^isolation: isolated$' "$TRANSCRIPT" \
  || harness_oracle_fail "GO/notes/block verdicts require isolation: isolated on this task"
grep -Eq '^runner: pi-child$' "$TRANSCRIPT" \
  || harness_oracle_fail "expected runner: pi-child"
harness_require_spawn_evidence
if [ "$(harness_extract_verdict "$TRANSCRIPT")" = "Verdict: GO" ]; then
  grep -Eq '^isolation: none$' "$TRANSCRIPT" \
    && harness_oracle_fail "GO with isolation: none in the same transcript"
fi
deciding_block="$(awk '/Deciding-code/{p=1; next} p && /^Verdict:/{exit} p' "$TRANSCRIPT")"
printf '%s\n' "$deciding_block" | grep -Eq '\|[^|]*[a-zA-Z0-9_./-]+:[0-9]' \
  || harness_oracle_fail "deciding-code section has no row with a file:line reference"
