#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_head_unchanged
harness_require_file_sha_eq "$WORKTREE/src/runtime.sh" "$TASK_DIR/uncommitted/src/runtime.sh"
harness_require_porcelain_allowlist 'src/runtime.sh' 'PLAN.md'

# State-derived isolation: pi is reachable on this task, so the only
# acceptable proof of a delegated hunt is an observed spawn. Self-declared
# lines and unavailable-sentinels are not evidence here (a sentinel would
# mean the agent failed to comply, not that isolation was impossible).
grep -Eq '^isolation: isolated$' "$TRANSCRIPT" \
  || harness_oracle_fail "expected isolation: isolated (pi is reachable on this task)"
grep -Eq '^runner: pi-child$' "$TRANSCRIPT" \
  || harness_oracle_fail "expected runner: pi-child"
harness_require_spawn_evidence
verdict="$(harness_require_verdict)"
if grep -Eq '^isolation: none$' "$TRANSCRIPT" && [ "$verdict" = "Verdict: GO" ]; then
  harness_oracle_fail "isolation: none plus Verdict: GO"
fi
