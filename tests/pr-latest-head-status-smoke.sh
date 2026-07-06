#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
HELPER="$ROOT_DIR/scripts/pr-latest-head-status"
FIXTURES="$ROOT_DIR/tests/fixtures/pr-maintenance"

assert_status() {
  local fixture="$1"
  local expected="$2"
  local actual

  actual="$("$HELPER" --json "$FIXTURES/$fixture" | jq -r '.status')"
  if [ "$actual" != "$expected" ]; then
    printf 'expected %s for %s, got %s\n' "$expected" "$fixture" "$actual" >&2
    "$HELPER" --json "$FIXTURES/$fixture" >&2
    exit 1
  fi
}

before_status="$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)"

assert_status clean-latest-head.json clean_latest_head
assert_status stale-review.json stale_review
assert_status needs-rerun.json needs_rerun
assert_status missing-latest-checks.json needs_rerun

text_output="$("$HELPER" "$FIXTURES/stale-review.json")"
case "$text_output" in
  *"status=stale_review"* ) ;;
  * )
    printf 'expected text output to include stale_review, got: %s\n' "$text_output" >&2
    exit 1
    ;;
esac

"$HELPER" --json "$FIXTURES/stale-review.json" |
  jq -e '
    .status == "stale_review" and
    .reason == "clean_review_does_not_apply_to_latest_head" and
    .latest_head_sha == "new456" and
    .stale_review_count == 1
  ' >/dev/null

"$HELPER" --json "$FIXTURES/missing-latest-checks.json" |
  jq -e '
    .status == "needs_rerun" and
    .reason == "latest_head_missing_checks" and
    .latest_head_sha == "zzz999" and
    .stale_review_count == 1 and
    .latest_check_count == 0
  ' >/dev/null

after_status="$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)"
if [ "$before_status" != "$after_status" ]; then
  printf 'pr-latest-head-status smoke mutated the worktree\n' >&2
  diff -u <(printf '%s\n' "$before_status") <(printf '%s\n' "$after_status") >&2 || true
  exit 1
fi

printf 'pr-latest-head-status smoke test: ok\n'
