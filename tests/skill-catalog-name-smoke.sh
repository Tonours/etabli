#!/usr/bin/env bash
set -euo pipefail

# Smoke for skill_declared_name slug validation in scripts/lib/skill-catalog.sh:
# a valid kebab name is kept; a display-case or invalid declaration falls back
# to the directory basename; a missing declaration falls back too.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
# shellcheck source=../../scripts/lib/skill-catalog.sh
. "$ROOT_DIR/scripts/lib/skill-catalog.sh"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

write_skill() {
  local dir="$1" name_line="$2"
  mkdir -p "$dir"
  {
    printf -- '---\n'
    [ -n "$name_line" ] && printf '%s\n' "$name_line"
    printf 'description: fixture\n---\nbody\n'
  } >"$dir/SKILL.md"
}

kebab="$TMP_DIR/how"
write_skill "$kebab" "name: how"
[ "$(skill_declared_name "$kebab")" = "how" ] ||
  fail "kebab declared name must be kept"

display="$TMP_DIR/poteto-mode"
write_skill "$display" "name: Poteto Mode"
[ "$(skill_declared_name "$display")" = "poteto-mode" ] ||
  fail "display-case name must fall back to directory basename"

spaces="$TMP_DIR/technical-writing"
write_skill "$spaces" "name: technical writing"
[ "$(skill_declared_name "$spaces")" = "technical-writing" ] ||
  fail "space-containing name must fall back to directory basename"

missing="$TMP_DIR/no-name"
write_skill "$missing" ""
[ "$(skill_declared_name "$missing")" = "no-name" ] ||
  fail "missing name must fall back to directory basename"

quoted="$TMP_DIR/quoted-name"
write_skill "$quoted" 'name: "quoted-name"'
[ "$(skill_declared_name "$quoted")" = "quoted-name" ] ||
  fail "quoted kebab name must be unquoted and kept"

printf 'PASS: skill-catalog name smoke\n'
