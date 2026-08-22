#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_contains "$WORKTREE/src/fixture.sh" '# harness-eval-marker'
harness_require_porcelain_allowlist 'src/fixture.sh' 'PLAN.md' 'docs/plan/' '.workflow/' 'docs/agent-memory/'
