#!/usr/bin/env bash
# tests/prompt-order-smoke.sh — T8a AC4 characterization + AC1 ship coverage.
#
# CHARACTERIZATION of the CURRENT hunter invocation (T8a takes no branch):
# the axis template travels via `--append-system-prompt`, the patch via
# `@file`, and `--patch-first` is ABSENT everywhere.
#
# T8b FLIP NOTE: when the Logic-only `--patch-first` reorder ships, this
# smoke MUST be rewritten to assert patch-before-template bytes, the absence
# of patch content from the system slot (role separation), the flag's
# presence on the Logic path, and its absence on the Spec/adversary paths.
# A passing characterization after the reorder would be a stale lie.
#
# Part 2 runs the AC1 ship-coverage check (required refs all listed).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HUNTER="$ROOT_DIR/scripts/pi-review-hunter"

fail() {
  printf 'prompt-order smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$HUNTER" ] || fail "missing hunter: $HUNTER"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'template bytes\n' >"$TMP/tmpl.md"
printf 'patch bytes\n' >"$TMP/patch.diff"

ARGV="$("$HUNTER" --print-argv --prompt-file "$TMP/tmpl.md" --patch "$TMP/patch.diff")"

# 1. template via --append-system-prompt ...
printf '%s\n' "$ARGV" | grep -qx -- '--append-system-prompt' \
  || fail "argv lacks --append-system-prompt (got: $ARGV)"
printf '%s\n' "$ARGV" | grep -qx -- "$TMP/tmpl.md" \
  || fail "argv lacks the prompt file after the flag"

# ... patch via @file, AFTER the template flag (current order).
printf '%s\n' "$ARGV" | grep -qx -- "@$TMP/patch.diff" \
  || fail "argv lacks @$TMP/patch.diff"
FLAG_LINE="$(printf '%s\n' "$ARGV" | grep -n -x -- '--append-system-prompt' | cut -d: -f1)"
PATCH_LINE="$(printf '%s\n' "$ARGV" | grep -n -x -- "@$TMP/patch.diff" | cut -d: -f1)"
[ "$FLAG_LINE" -lt "$PATCH_LINE" ] \
  || fail "current order changed: @patch (line $PATCH_LINE) no longer after --append-system-prompt (line $FLAG_LINE)"

# 2. --patch-first ABSENT from the argv and from the hunter script.
printf '%s\n' "$ARGV" | grep -q -- '--patch-first' \
  && fail "argv unexpectedly carries --patch-first"
grep -q -- '--patch-first' "$HUNTER" \
  && fail "hunter script unexpectedly carries --patch-first"

echo "prompt-order smoke: characterization green (template-via---append-system-prompt + patch-via-@file + --patch-first absent)"

# 3. AC1 ship-coverage part.
"$ROOT_DIR/scripts/ship-coverage-check" \
  || fail "ship-coverage-check failed"
echo "prompt-order smoke: PASS"
