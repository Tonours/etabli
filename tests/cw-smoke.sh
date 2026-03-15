#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TEST_DIR="$(mktemp -d)"
BIN_DIR="${TEST_DIR}/bin"
PROJECT_ROOT="${TEST_DIR}/projects"
ORIGIN_DIR="${TEST_DIR}/origin.git"
REPO_DIR="${PROJECT_ROOT}/demo"
CW_SCRIPT="${ROOT_DIR}/scripts/cw"
BASH_BIN="$(command -v bash)"

cleanup() {
    /bin/rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR" "$PROJECT_ROOT"
for cmd in git awk sed tr dirname basename readlink mkdir head grep mktemp sort; do
    ln -sf "$(command -v "$cmd")" "${BIN_DIR}/${cmd}"
done

export PATH="$BIN_DIR"
export CW_PROJECT_ROOT="$PROJECT_ROOT"
export CW_DEFAULT_AGENT="none"

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if ! grep -Fq "$needle" <<<"$haystack"; then
        printf "expected to find: %s\n" "$needle" >&2
        printf "%s\n" "$haystack" >&2
        exit 1
    fi
}

git init --bare "$ORIGIN_DIR" >/dev/null

git clone "$ORIGIN_DIR" "$REPO_DIR" >/dev/null 2>&1
REPO_DIR="$(cd "$REPO_DIR" >/dev/null 2>&1 && pwd -P)"

git -C "$REPO_DIR" config user.name "Test User"
git -C "$REPO_DIR" config user.email "test@example.com"
git -C "$REPO_DIR" switch -c main >/dev/null
echo ".worktrees/" >"${REPO_DIR}/.gitignore"
echo "root" >"${REPO_DIR}/README.md"
git -C "$REPO_DIR" add .gitignore README.md
git -C "$REPO_DIR" commit -m "init" >/dev/null
git -C "$REPO_DIR" push -u origin main >/dev/null 2>&1

cd "$REPO_DIR"
create_output="$($BASH_BIN "$CW_SCRIPT" demo 'Feature One' fix --no-fetch -n -P 2>&1)"
assert_contains "$create_output" "Branch: fix/feature-one (base: origin/main)"
assert_contains "$create_output" ".worktrees/fix-feature-one"
assert_contains "$create_output" "warning: tmux not found"

WORKTREE_PATH="${REPO_DIR}/.worktrees/fix-feature-one"
[ -d "$WORKTREE_PATH" ]
[ "$(git -C "$WORKTREE_PATH" branch --show-current)" = "fix/feature-one" ]

echo "feature" >"${WORKTREE_PATH}/feature.txt"
git -C "$WORKTREE_PATH" add feature.txt
git -C "$WORKTREE_PATH" commit -m "feature" >/dev/null

ls_output="$($BASH_BIN "$CW_SCRIPT" ls demo 2>&1)"
assert_contains "$ls_output" "fix/feature-one -> ${WORKTREE_PATH}"

open_output="$($BASH_BIN "$CW_SCRIPT" open demo fix/feature-one -P 2>&1)"
assert_contains "$open_output" "warning: tmux not found"
assert_contains "$open_output" "$WORKTREE_PATH"

merge_dry_run="$($BASH_BIN "$CW_SCRIPT" merge demo fix/feature-one 2>&1)"
assert_contains "$merge_dry_run" "Dry-run. Re-run with --yes to merge."

merge_apply="$($BASH_BIN "$CW_SCRIPT" merge demo fix/feature-one --yes 2>&1)"
assert_contains "$merge_apply" "Merged fix/feature-one into main"

rm_dry_run="$($BASH_BIN "$CW_SCRIPT" rm demo fix/feature-one 2>&1)"
assert_contains "$rm_dry_run" "Merged:  yes"
assert_contains "$rm_dry_run" "Dry-run. Re-run with --yes to remove."

rm_apply="$($BASH_BIN "$CW_SCRIPT" rm demo fix/feature-one --yes 2>&1)"
assert_contains "$rm_apply" "Removed fix/feature-one"
[ ! -d "$WORKTREE_PATH" ]

echo "cw smoke test: ok"
