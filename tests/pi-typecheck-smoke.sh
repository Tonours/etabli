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

# pi/durable imports the sibling pi-mobile checkout, which CI does not have.
# Only the unresolved pi-mobile imports are tolerated; every other diagnostic fails.
DURABLE_DIR="$ROOT_DIR/pi/durable"
if [ ! -d "$DURABLE_DIR/node_modules" ]; then
  printf 'Pi durable typecheck: pi/durable/node_modules is missing; run npm ci --prefix pi/durable\n' >&2
  exit 1
fi
set +e
npm run --silent typecheck --prefix "$DURABLE_DIR" >"$TMP_DIR/durable-tsc.log" 2>&1
DURABLE_STATUS=$?
set -e
if [ "$DURABLE_STATUS" -ne 0 ] && ! grep -q ': error TS[0-9]*:' "$TMP_DIR/durable-tsc.log"; then
  cat "$TMP_DIR/durable-tsc.log" >&2
  printf 'Pi durable typecheck exited %s without diagnostics\n' "$DURABLE_STATUS" >&2
  exit 1
fi
if grep ': error TS[0-9]*:' "$TMP_DIR/durable-tsc.log" |
  grep -v "error TS2307: Cannot find module '[^']*pi-mobile/" >&2; then
  printf 'Pi durable typecheck failed; full output:\n' >&2
  cat "$TMP_DIR/durable-tsc.log" >&2
  exit 1
fi

printf 'Pi typecheck smoke test: ok\n'
