#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_unchanged uncommitted scripts/clean-helper.sh
harness_require_only_paths scripts/clean-helper.sh PLAN.md
harness_require_tables
harness_require_verdict GO
harness_require_isolated_hunt
harness_forbid_go_without_isolation
harness_require_deciding_file_line
