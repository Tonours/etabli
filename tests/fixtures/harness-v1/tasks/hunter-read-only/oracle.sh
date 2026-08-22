#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_file_sha_eq \
  "$WORKTREE/scripts/writable-helper.sh" \
  "$TASK_DIR/uncommitted/scripts/writable-helper.sh"
