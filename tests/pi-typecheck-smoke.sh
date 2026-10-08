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
# Only the unresolved pi-mobile imports and the implicit-any errors they cause
# in the importing files are tolerated; every other diagnostic fails.
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
if ! awk '
  /^[^ ].*: error TS[0-9]+:/ {
    file = substr($0, 1, index($0, "(") - 1)
    if ($0 ~ /error TS2307: Cannot find module .[^ ]*pi-mobile\//) { sibling[file] = 1; next }
    n++; line[n] = $0; owner[n] = file
  }
  END {
    for (i = 1; i <= n; i++) {
      if (sibling[owner[i]] && line[i] ~ /error TS7006:/) continue
      print line[i]; bad = 1
    }
    exit bad
  }
' "$TMP_DIR/durable-tsc.log" >&2; then
  printf 'Pi durable typecheck failed; full output:\n' >&2
  cat "$TMP_DIR/durable-tsc.log" >&2
  exit 1
fi

printf 'Pi typecheck smoke test: ok\n'
