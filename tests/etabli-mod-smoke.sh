#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
MODS_DIR="$ROOT_DIR/claude/mods"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

if ! command -v claude >/dev/null 2>&1; then
  printf 'SKIP: etabli-mod-smoke needs the claude CLI; the mod was not validated\n'
  exit 0
fi

claude plugin validate "$MODS_DIR" >/dev/null || fail "marketplace manifest in claude/mods does not validate"
claude plugin validate "$MODS_DIR/etabli" >/dev/null || fail "etabli mod does not validate"
(cd "$MODS_DIR/etabli" && claude plugin test .) >/dev/null || fail "etabli mod tests fail"

printf 'etabli-mod-smoke: ok\n'
