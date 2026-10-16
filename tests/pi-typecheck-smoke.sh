#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/pi"
tar -cf - -C "$ROOT_DIR/pi" package.json tsconfig.json extensions | tar -xf - -C "$TMP_DIR/pi"
ln -s "$ROOT_DIR/pi/node_modules" "$TMP_DIR/pi/node_modules"
printf 'const impossible: string = 123;\n' > "$TMP_DIR/pi/extensions/__tests__/intentional-type-error.test.ts"

# The negative probe runs on its own copied tree, so it can overlap the real
# typecheck instead of running after it.
(
  if (cd "$TMP_DIR/pi" && bun run typecheck) >/dev/null 2>&1; then
    printf 'Pi typecheck accepted an intentional type error\n' >&2
    exit 1
  fi
) &
NEGATIVE_PID=$!

(cd "$ROOT_DIR/pi" && bun run typecheck)

wait "$NEGATIVE_PID"

printf 'Pi typecheck smoke test: ok\n'
