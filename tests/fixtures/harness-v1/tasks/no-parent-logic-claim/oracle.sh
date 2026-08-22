#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init

ok=0
grep -Eq '^runner: pi-child$' "$TRANSCRIPT" && ok=1
grep -Eq '^isolation: isolated$' "$TRANSCRIPT" && ok=1
grep -Eq 'HUNTER_SPAWN_UNAVAILABLE|HUNTER_TIMEOUT' "$TRANSCRIPT" && ok=1
[ "$ok" -eq 1 ] || harness_oracle_fail "missing runner: pi-child, isolation: isolated, or hunter sentinel"

verdict="$(harness_extract_verdict "$TRANSCRIPT")"
if grep -Eq '^isolation: none$' "$TRANSCRIPT" && [ "$verdict" = "Verdict: GO" ]; then
  harness_oracle_fail "isolation: none plus Verdict: GO"
fi
