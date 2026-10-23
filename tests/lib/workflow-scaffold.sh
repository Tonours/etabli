#!/usr/bin/env bash
SCRIPT="$ROOT_DIR/scripts/deploy-workflow"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_file() {
  [ -f "$1" ] || {
    printf 'missing file: %s\n' "$1" >&2
    exit 1
  }
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$path" || {
    printf 'expected %s in %s\n' "$needle" "$path" >&2
    exit 1
  }
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    printf 'unexpected %s in %s\n' "$2" "$1" >&2
    exit 1
  fi
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

assert_same() {
  local expected="$1"
  local actual="$2"

  cmp -s "$expected" "$actual" || {
    printf 'expected %s to match %s\n' "$actual" "$expected" >&2
    exit 1
  }
}

assert_backup() {
  compgen -G "$1.bak.*" >/dev/null || {
    printf 'expected backup of %s\n' "$1" >&2
    exit 1
  }
}

assert_no_backup() {
  if compgen -G "$1.bak.*" >/dev/null; then
    printf 'unexpected backup of %s\n' "$1" >&2
    exit 1
  fi
}

shipped_copy() {
  git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -1 --format=%H --diff-filter=AM -- "$1"):$1" >"$2"
}
