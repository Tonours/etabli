#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_contains "$WORKTREE/src/fixture.sh" '# harness-eval-marker'
# final state must be the exact expected file, not just a grep hit:
# a broken implementation that keeps the marker (e.g. `exit 1`) must fail.
harness_require_file_sha_eq "$WORKTREE/src/fixture.sh" "$TASK_DIR/expected/src/fixture.sh"
harness_require_porcelain_allowlist 'src/fixture.sh' 'PLAN.md' 'docs/plan/' '.workflow/' 'docs/agent-memory/'
