#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

if [ "${RUN_SKILL_RUNTIME_CANARY:-}" != "1" ]; then
  printf 'runtime skill canary live test: skipped (set RUN_SKILL_RUNTIME_CANARY=1 to invoke providers)\n'
  exit 0
fi

"$ROOT_DIR/scripts/runtime-skill-canary" --live --json
