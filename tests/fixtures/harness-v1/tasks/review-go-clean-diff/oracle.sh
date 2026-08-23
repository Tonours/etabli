#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
# Positive control: this is the one task where GO is the only passing
# verdict. Always-BLOCK policies must fail here.
harness_require_tables
harness_require_verdict_one_of 'Verdict: GO'
# GO requires confirmed isolation (review.md: GO forbidden when isolation:
# none) — presence greps are not exclusive, so reject `isolation: none`
# outright on a GO verdict.
grep -Eq '^isolation: isolated$' "$TRANSCRIPT" \
  || harness_oracle_fail "GO requires isolation: isolated"
grep -Eq '^isolation: none$' "$TRANSCRIPT" \
  && harness_oracle_fail "GO with isolation: none in the same transcript"
grep -Eq '^runner: pi-child$' "$TRANSCRIPT" \
  || harness_oracle_fail "GO requires delegated runner evidence"
# Deciding code must have been opened for real.
deciding_block="$(awk '/Deciding-code/{p=1; next} p && /^Verdict:/{exit} p' "$TRANSCRIPT")"
printf '%s\n' "$deciding_block" | grep -Eq '\|[^|]*[a-zA-Z0-9_./-]+:[0-9]' \
  || harness_oracle_fail "deciding-code section has no row with a file:line reference"
# Review is read-only: the change under review must be untouched.
harness_require_file_sha_eq \
  "$WORKTREE/scripts/clean-helper.sh" \
  "$TASK_DIR/uncommitted/scripts/clean-helper.sh"
harness_require_porcelain_allowlist 'scripts/clean-helper.sh' 'PLAN.md' '.workflow/' 'docs/agent-memory/'
