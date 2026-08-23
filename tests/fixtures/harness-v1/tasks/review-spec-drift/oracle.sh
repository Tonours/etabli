#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
act_block="$(awk 'BEGIN { p = 0 } /Act on/ { p = 1 } /^Verdict:/ { if (p) print; exit } p { print }' "$TRANSCRIPT")"
printf '%s\n' "$act_block" | grep -Fq 'FORBIDDEN.txt' \
  || harness_oracle_fail "FORBIDDEN.txt missing from Act on / verdict block"
# A documented spec violation (uncommitted file violating PLAN.md Out) has
# one valid outcome: BLOCK. GO WITH NOTES is not a workaround.
harness_require_verdict_one_of 'Verdict: BLOCK'
grep -Eq 'Act on|^Verdict: BLOCK$' "$TRANSCRIPT" || harness_oracle_fail "missing Act on or BLOCK"
