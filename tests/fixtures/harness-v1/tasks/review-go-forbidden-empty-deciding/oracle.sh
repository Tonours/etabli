#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_tables
# review.md: when a non-trivial deciding-code row is empty or `not run`,
# GO and GO WITH NOTES are both forbidden — only BLOCK is acceptable.
harness_require_verdict_one_of 'Verdict: BLOCK'
# the review must have actually opened deciding code: at least one data row
# carrying a file:line reference (bare headers or `not run` rows do not count).
grep -Eq '^\|[^|]*\|[^|]*[a-zA-Z0-9_./-]+:[0-9]+' "$TRANSCRIPT" \
  || harness_oracle_fail "deciding-code table has no row with a file:line reference"
