#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_tables
harness_require_verdict_one_of 'Verdict: BLOCK' 'Verdict: GO WITH NOTES'
