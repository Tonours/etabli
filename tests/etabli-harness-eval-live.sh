#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

if [ "${ETABLI_HARNESS_EVAL:-}" != "1" ]; then
  printf 'etabli harness eval live: skipped (set ETABLI_HARNESS_EVAL=1 to invoke Pi/Grok)\n'
  exit 0
fi

"$ROOT_DIR/scripts/etabli-harness-eval" run --runner pi --task review-isolation-sentinel
