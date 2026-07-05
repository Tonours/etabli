#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/good.md" <<'MD'
# Research

Status: confirmed.

Sources:
- https://example.com/source

Finding: the cited behavior is confirmed by the source.
MD

cat >"$TMP_DIR/no-source.md" <<'MD'
# Research

Status: confirmed.

Finding: I searched the web and it works.
MD

cat >"$TMP_DIR/no-label.md" <<'MD'
# Research

Sources:
- https://example.com/source

Finding: the source says it works.
MD

"$ROOT_DIR/scripts/research-proof-check" "$TMP_DIR/good.md" >/dev/null

if "$ROOT_DIR/scripts/research-proof-check" "$TMP_DIR/no-source.md" >/dev/null 2>&1; then
  printf 'research proof check should fail without source evidence\n' >&2
  exit 1
fi

if "$ROOT_DIR/scripts/research-proof-check" "$TMP_DIR/no-label.md" >/dev/null 2>&1; then
  printf 'research proof check should fail without confidence label\n' >&2
  exit 1
fi

printf 'research proof check smoke test: ok\n'
