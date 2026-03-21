#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

assert_file() {
    [ -f "$1" ] || {
        printf 'missing file: %s\n' "$1" >&2
        exit 1
    }
}

assert_contains() {
    local path="$1"
    local needle="$2"

    grep -Fq "$needle" "$path" || {
        printf 'expected %s in %s\n' "$needle" "$path" >&2
        exit 1
    }
}

assert_not_contains() {
    local path="$1"
    local needle="$2"

    if grep -Fq "$needle" "$path"; then
        printf 'did not expect %s in %s\n' "$needle" "$path" >&2
        exit 1
    fi
}

assert_file "$ROOT_DIR/workflow/review-rubric.md"
assert_file "$ROOT_DIR/workflow/handoff-template.md"

assert_contains "$ROOT_DIR/scripts/install.sh" 'workflow/$shared_doc'
assert_contains "$ROOT_DIR/pi/extensions/handoff.ts" 'workflow/handoff-template.md'
assert_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'workflow/review-rubric.md'
assert_not_contains "$ROOT_DIR/pi/skills/review/SKILL.md" 'claude/review-rubric.md'

printf 'workflow docs smoke test: ok\n'
