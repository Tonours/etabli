#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
OUTPUT="$(ETABLI_INSTALL_HELPER_SMOKE=1 "$ROOT_DIR/scripts/install.sh")"

case "$OUTPUT" in
  *"install helper smoke test: ok"*) ;;
  *)
    printf 'unexpected install helper smoke output:\n%s\n' "$OUTPUT" >&2
    exit 1
    ;;
esac

printf 'install smoke test: ok\n'
