#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/extras/skills/browser-full-page-capture/scripts/stitch-full-page-capture.mjs"
FIXTURE="$ROOT_DIR/tests/fixtures/full-page-capture/page.html"

node --check "$HELPER"
node --test "$ROOT_DIR"/extras/skills/browser-full-page-capture/scripts/*.test.mjs
node "$HELPER" --help | grep -q -- '--viewport'
grep -q 'position: fixed' "$FIXTURE"
grep -q 'position: sticky' "$FIXTURE"
grep -q 'IntersectionObserver' "$FIXTURE"
grep -q 'Footer evidence' "$FIXTURE"

if [ "${RUN_BROWSER_CAPTURE_SMOKE:-0}" != "1" ]; then
  printf 'browser full-page capture smoke: deterministic checks ok; live check skipped\n'
  exit 0
fi

command -v ffmpeg >/dev/null || { printf 'ffmpeg unavailable\n' >&2; exit 1; }
node -e 'require("playwright")' || { printf 'playwright unavailable\n' >&2; exit 1; }
command -v python3 >/dev/null || { printf 'python3 unavailable for local fixture server\n' >&2; exit 1; }
TMP_DIR="$(mktemp -d)"
python3 -m http.server 43871 --directory "$(dirname "$FIXTURE")" >"$TMP_DIR/server.log" 2>&1 &
server_pid=$!
cleanup() { kill "$server_pid" 2>/dev/null || true; rm -rf "$TMP_DIR"; }
trap cleanup EXIT
node "$HELPER" --url http://127.0.0.1:43871/page.html --out "$TMP_DIR/page.jpg" --viewport 800x500 --step 400 --wait 50
test -s "$TMP_DIR/page.jpg"
printf 'browser full-page capture smoke: live fixture ok\n'
