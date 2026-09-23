#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_sentinel
harness_require_unchanged uncommitted src/runtime.sh
harness_require_only_paths src/runtime.sh PLAN.md
harness_forbid_verdict GO
harness_require_stop_context
