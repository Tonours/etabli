#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_DIR="$(mktemp -d)"
trap 'rm -rf "$PROBE_DIR"' EXIT
mkdir -p "$PROBE_DIR/.workflow/guard-journal"
printf 'preserved\n' > "$PROBE_DIR/.workflow/guard-journal/sentinel"

cd "$PROBE_DIR"
bun test "$ROOT_DIR/pi/extensions/__tests__/no-comments-extension.test.ts" > pi.log 2>&1 || {
  cat pi.log >&2
  exit 1
}
bash "$ROOT_DIR/tests/claude-hooks-smoke.sh" > claude.log 2>&1 || {
  cat claude.log >&2
  exit 1
}
node --input-type=module -e '
  import { readdirSync, readFileSync } from "node:fs";
  const dir = ".workflow/guard-journal";
  if (readdirSync(dir).join() !== "sentinel" || readFileSync(`${dir}/sentinel`, "utf8") !== "preserved\n") {
    console.error("guard-journal-isolation: FAIL: tests polluted invocation journal; pass a disposable cwd to every guard fixture");
    process.exit(1);
  }
'
printf 'guard-journal-isolation: PASS\n'
