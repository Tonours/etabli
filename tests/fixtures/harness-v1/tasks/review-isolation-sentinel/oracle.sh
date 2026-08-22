#!/usr/bin/env bash
set -euo pipefail
source "${ETABLI_HARNESS_LIB:?}"
harness_oracle_init
harness_require_transcript_re 'HUNTER_SPAWN_UNAVAILABLE|HUNTER_TIMEOUT'
verdict="$(harness_extract_verdict "$TRANSCRIPT")"
[ "$verdict" != "Verdict: GO" ] || harness_oracle_fail "final verdict must not be GO"
