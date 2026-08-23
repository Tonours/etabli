#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_file_sha_eq "$WORKTREE/src/product.sh" "$TASK_DIR/overlay/src/product.sh"
# DRAFT scope: only the active root PLAN.md may change. Archiving to
# docs/plan/ is a completion-time escape (plan-cleanup), never allowed
# while the plan is DRAFT.
harness_require_porcelain_allowlist 'PLAN.md' '.workflow/' 'docs/agent-memory/'
