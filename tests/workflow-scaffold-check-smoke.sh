#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/tests/lib/workflow-scaffold.sh"

NEW_PROJECT="$TMP_DIR/new-project"
"$SCRIPT" "$NEW_PROJECT" >/dev/null

CHECK_CLEAN_OUTPUT="$TMP_DIR/check-clean.out"
"$SCRIPT" "$NEW_PROJECT" --check >"$CHECK_CLEAN_OUTPUT"
assert_contains "$CHECK_CLEAN_OUTPUT" "OK        workflow/spec.md"
assert_contains "$CHECK_CLEAN_OUTPUT" "Summary: 0 drifted, 0 missing"

CHECK_DRIFT_PROJECT="$TMP_DIR/check-drift-project"
CHECK_DRIFT_OUTPUT="$TMP_DIR/check-drift.out"
"$SCRIPT" "$CHECK_DRIFT_PROJECT" >/dev/null
printf '\nlocal change\n' >>"$CHECK_DRIFT_PROJECT/workflow/spec.md"
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- workflow/answer-quality.md | tail -1):workflow/answer-quality.md" >"$CHECK_DRIFT_PROJECT/workflow/answer-quality.md"
git -C "$ROOT_DIR" show HEAD:AGENTS.md >"$CHECK_DRIFT_PROJECT/AGENTS.md"
rm "$CHECK_DRIFT_PROJECT/PLAN_TEMPLATE.md"
find "$CHECK_DRIFT_PROJECT" -print | sort >"$TMP_DIR/check-drift.before"
if "$SCRIPT" "$CHECK_DRIFT_PROJECT" --check >"$CHECK_DRIFT_OUTPUT" 2>&1; then
  printf 'expected deploy --check to fail on drifted project\n' >&2
  exit 1
fi
find "$CHECK_DRIFT_PROJECT" -print | sort >"$TMP_DIR/check-drift.after"
if ! diff -u "$TMP_DIR/check-drift.before" "$TMP_DIR/check-drift.after"; then
  printf 'deploy --check mutated the checked project\n' >&2
  exit 1
fi
assert_contains "$CHECK_DRIFT_OUTPUT" "EDITED    workflow/spec.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "STALE     workflow/answer-quality.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "EDITED    AGENTS.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "MISSING   PLAN_TEMPLATE.md"
assert_contains "$CHECK_DRIFT_OUTPUT" "Summary: 3 drifted, 1 missing"
assert_contains "$CHECK_DRIFT_OUTPUT" "Fix: $SCRIPT $(cd "$CHECK_DRIFT_PROJECT" && pwd) writes MISSING and refreshes STALE copies; review EDITED copies, then rerun it with --force"
assert_contains "$CHECK_DRIFT_PROJECT/workflow/spec.md" "local change"
assert_not_exists "$CHECK_DRIFT_PROJECT/PLAN_TEMPLATE.md"

CHECK_FLAG_OUTPUT="$TMP_DIR/check-flags.out"
if "$SCRIPT" "$NEW_PROJECT" --check --force >"$CHECK_FLAG_OUTPUT" 2>&1; then
  printf 'expected deploy --check --force to fail\n' >&2
  exit 1
fi
assert_contains "$CHECK_FLAG_OUTPUT" "flags are mutually exclusive"

if "$SCRIPT" "$NEW_PROJECT" --check --dry-run >"$CHECK_FLAG_OUTPUT" 2>&1; then
  printf 'expected deploy --check --dry-run to fail\n' >&2
  exit 1
fi
assert_contains "$CHECK_FLAG_OUTPUT" "flags are mutually exclusive"

STALE_PROJECT="$TMP_DIR/stale-project"
"$SCRIPT" "$STALE_PROJECT" >/dev/null
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- workflow/answer-quality.md | tail -1):workflow/answer-quality.md" >"$STALE_PROJECT/workflow/answer-quality.md"
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- scripts/plan-cleanup | tail -1):scripts/plan-cleanup" >"$STALE_PROJECT/scripts/plan-cleanup"
ln "$STALE_PROJECT/workflow/answer-quality.md" "$TMP_DIR/stale-hardlink"
cp "$TMP_DIR/stale-hardlink" "$TMP_DIR/stale-hardlink.before"
"$SCRIPT" "$STALE_PROJECT" --dry-run >"$TMP_DIR/stale-dry.out"
assert_contains "$TMP_DIR/stale-dry.out" "WOULD_REFRESH workflow/answer-quality.md"
"$SCRIPT" "$STALE_PROJECT" >"$TMP_DIR/stale.out"
assert_contains "$TMP_DIR/stale.out" "REFRESH   workflow/answer-quality.md"
assert_same "$ROOT_DIR/workflow/answer-quality.md" "$STALE_PROJECT/workflow/answer-quality.md"
assert_same "$TMP_DIR/stale-hardlink.before" "$TMP_DIR/stale-hardlink"
if compgen -G "$STALE_PROJECT/workflow/answer-quality.md.bak.*" >/dev/null; then
  printf 'a STALE refresh left a backup\n' >&2
  exit 1
fi
file_mode() {
  if stat -c %a "$1" >/dev/null 2>&1; then stat -c %a "$1"; else stat -f %Lp "$1"; fi
}
[ "$(file_mode "$STALE_PROJECT/scripts/plan-cleanup")" = "$(file_mode "$ROOT_DIR/scripts/plan-cleanup")" ] || {
  printf 'a refresh changed the mode of scripts/plan-cleanup\n' >&2
  exit 1
}
if find "$STALE_PROJECT" -name '*etabli-refresh*' | grep -q .; then
  printf 'a refresh left a temporary file\n' >&2
  exit 1
fi
git -C "$ROOT_DIR" cat-file blob 4eb78fb >"$STALE_PROJECT/AGENTS.md"
"$SCRIPT" "$STALE_PROJECT" --check >"$TMP_DIR/stale-renamed.out" 2>&1 || true
assert_contains "$TMP_DIR/stale-renamed.out" "STALE     AGENTS.md"
"$SCRIPT" "$STALE_PROJECT" >/dev/null
"$SCRIPT" "$STALE_PROJECT" --check >/dev/null
STALE_OUTSIDE="$TMP_DIR/stale-outside"
mkdir -p "$STALE_OUTSIDE"
mv "$STALE_PROJECT/workflow" "$STALE_OUTSIDE/workflow"
ln -s "$STALE_OUTSIDE/workflow" "$STALE_PROJECT/workflow"
git -C "$ROOT_DIR" show "$(git -C "$ROOT_DIR" log -2 --format=%H -- workflow/answer-quality.md | tail -1):workflow/answer-quality.md" >"$STALE_OUTSIDE/workflow/answer-quality.md"
cp "$STALE_OUTSIDE/workflow/answer-quality.md" "$TMP_DIR/stale-outside.before"
if "$SCRIPT" "$STALE_PROJECT" >"$TMP_DIR/stale-outside.out" 2>&1; then
  printf 'expected a refresh through a symlinked parent to conflict\n' >&2
  exit 1
fi
assert_contains "$TMP_DIR/stale-outside.out" "CONFLICT  workflow/answer-quality.md exists"
assert_same "$TMP_DIR/stale-outside.before" "$STALE_OUTSIDE/workflow/answer-quality.md"

printf 'workflow scaffold check smoke test: ok\n'
