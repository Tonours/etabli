#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
VALIDATOR="$ROOT_DIR/scripts/validate-adrs"
FIXTURE_DIR="$ROOT_DIR/tests/fixtures/adr-validation"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

compare_output() {
  local expected="$1" actual="$2" label="$3"
  if [ -f "$expected" ]; then
    if ! diff -u "$expected" "$actual"; then
      fail "$label did not match golden output"
    fi
    return
  fi

  if [ -s "$actual" ]; then
    printf '%s\n' "Unexpected $label:" >&2
    cat "$actual" >&2
    fail "$label should be empty"
  fi
}

command -v node >/dev/null || fail "node not on PATH"

while IFS= read -r case_dir; do
  name="$(basename "$case_dir")"
  repo="$TMP_DIR/$name"
  mkdir -p "$repo"
  cp -R "$case_dir/repo/." "$repo"

  expected_status="$(tr -d '\n' < "$case_dir/expected.status")"
  actual_stdout="$TMP_DIR/$name.stdout"
  actual_stderr="$TMP_DIR/$name.stderr"

  set +e
  node "$VALIDATOR" "$repo" >"$actual_stdout" 2>"$actual_stderr"
  actual_status="$?"
  set -e

  if [ "$actual_status" != "$expected_status" ]; then
    printf 'Expected status %s for %s, got %s\n' "$expected_status" "$name" "$actual_status" >&2
    printf 'stdout:\n' >&2
    cat "$actual_stdout" >&2
    printf 'stderr:\n' >&2
    cat "$actual_stderr" >&2
    fail "$name returned unexpected status"
  fi

  compare_output "$case_dir/expected.stdout" "$actual_stdout" "$name stdout"
  compare_output "$case_dir/expected.stderr" "$actual_stderr" "$name stderr"
done < <(find "$FIXTURE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

printf 'adr validation golden fixtures: ok\n'
