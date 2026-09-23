#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_unchanged overlay src/product.sh
harness_require_only_paths PLAN.md
