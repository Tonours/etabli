#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_tables
# review.md: when a non-trivial deciding-code row is empty or `not run`,
# GO and GO WITH NOTES are both forbidden — only BLOCK is acceptable.
harness_require_verdict_one_of 'Verdict: BLOCK'
# the review must have actually opened deciding code: the deciding-code
# section itself (not the lens table) must carry a file:line reference.
deciding_block="$(awk '/Deciding-code/{p=1; next} p && /^Verdict:/{exit} p' "$TRANSCRIPT")"
printf '%s\n' "$deciding_block" | grep -Eq '\|[^|]*[a-zA-Z0-9_./-]+:[0-9]' \
  || harness_oracle_fail "deciding-code section has no row with a file:line reference"
