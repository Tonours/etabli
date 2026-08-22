#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_file_sha_eq "$WORKTREE/src/product.sh" "$TASK_DIR/overlay/src/product.sh"
harness_require_porcelain_allowlist 'PLAN.md' 'docs/plan/' '.workflow/' 'docs/agent-memory/'
