#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_file_sha_eq "$WORKTREE/src/runtime.sh" "$TASK_DIR/uncommitted/src/runtime.sh"
harness_require_porcelain_allowlist 'src/runtime.sh' 'PLAN.md' '.workflow/' 'docs/agent-memory/'

# Exhaustive isolation signature: a single self-declared line is not proof.
# Two exclusive paths (presence greps are not exclusive, so `isolation: none`
# is checked unconditionally first):
#   - isolated pair: `isolation: isolated` + `runner: pi-child` + verdict
#   - unavailable sentinel: HUNTER_* + `isolation: none` + `runner: not run`
#     + non-GO verdict
verdict="$(harness_require_verdict)"

# Unconditional: `isolation: none` anywhere in the transcript forbids GO
# (review.md gate), even alongside an isolated-looking pair.
if grep -Eq '^isolation: none$' "$TRANSCRIPT" && [ "$verdict" = "Verdict: GO" ]; then
  harness_oracle_fail "isolation: none plus Verdict: GO"
fi

if grep -Eq '^isolation: isolated$' "$TRANSCRIPT" && \
   grep -Eq '^runner: pi-child$' "$TRANSCRIPT"; then
  exit 0
fi

if grep -Eq 'HUNTER_SPAWN_UNAVAILABLE|HUNTER_TIMEOUT' "$TRANSCRIPT" && \
   grep -Eq '^isolation: none$' "$TRANSCRIPT" && \
   grep -Eq '^runner: not run$' "$TRANSCRIPT"; then
  exit 0
fi

harness_oracle_fail "incomplete isolation signature: need isolation+runner (isolated) or sentinel+isolation:none+runner:not-run"
