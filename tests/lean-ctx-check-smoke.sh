#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/with-fallback.md" <<'MD'
# AGENTS

Prefer lean-ctx. If lean-ctx is unavailable, fall back immediately to native
shell/read/search commands.
MD

cat >"$TMP_DIR/no-fallback.md" <<'MD'
# AGENTS

Prefer lean-ctx for everything.
MD

json_output="$("$ROOT_DIR/scripts/lean-ctx-check" --agents "$TMP_DIR/with-fallback.md" --json)"
printf '%s\n' "$json_output" | jq -e 'has("available") and has("fallback_documented")' >/dev/null
"$ROOT_DIR/scripts/lean-ctx-check" --agents "$TMP_DIR/with-fallback.md" >/dev/null

if ! command -v lean-ctx >/dev/null 2>&1; then
  if "$ROOT_DIR/scripts/lean-ctx-check" --agents "$TMP_DIR/no-fallback.md" >/dev/null 2>&1; then
    printf 'lean-ctx-check should fail when lean-ctx is unavailable and fallback is undocumented\n' >&2
    exit 1
  fi
fi

printf 'lean-ctx check smoke test: ok\n'
