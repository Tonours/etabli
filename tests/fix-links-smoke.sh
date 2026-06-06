#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-fix-symlinks.sh"
TMP_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

assert_link() {
  local link_path="$1"
  local target_path="$2"

  if [ ! -L "$link_path" ]; then
    printf 'expected symlink: %s\n' "$link_path" >&2
    exit 1
  fi

  if [ "$(readlink "$link_path")" != "$target_path" ]; then
    printf 'expected %s -> %s, got %s\n' "$link_path" "$target_path" "$(readlink "$link_path")" >&2
    exit 1
  fi
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
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

backup_count() {
  find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak.*" | wc -l | tr -d ' '
}

HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null
HOME="$TMP_HOME" "$SCRIPT" --verbose >/dev/null

assert_link "$TMP_HOME/.config/nvim" "$ROOT_DIR/nvim"
assert_link "$TMP_HOME/.tmux.conf" "$ROOT_DIR/tmux.conf"
assert_link "$TMP_HOME/.config/ghostty/config" "$ROOT_DIR/ghostty/config"
assert_link "$TMP_HOME/.pi/agent/skills/review" "$ROOT_DIR/pi/skills/review"
assert_link "$TMP_HOME/.pi/agent/skills/plan-loop" "$ROOT_DIR/pi/skills/plan-loop"
assert_link "$TMP_HOME/.claude/commands/review.md" "$ROOT_DIR/claude/commands/review.md"
assert_not_exists "$TMP_HOME/.claude/skills/grill-me"

rm "$TMP_HOME/.pi/settings.json"
printf 'custom one\n' > "$TMP_HOME/.pi/settings.json"
HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null

rm "$TMP_HOME/.pi/settings.json"
printf 'custom two\n' > "$TMP_HOME/.pi/settings.json"
HOME="$TMP_HOME" "$SCRIPT" --fix --verbose >/dev/null

if [ "$(backup_count "$TMP_HOME/.pi/settings.json")" -lt 2 ]; then
  printf 'expected repeated fixes to keep distinct settings.json backups\n' >&2
  exit 1
fi

FAKE_REPO="$TMP_HOME/fake-repo"
FAKE_HOME="$TMP_HOME/fake-home"
MISSING_SOURCE_OUTPUT="$TMP_HOME/missing-source.out"
mkdir -p "$FAKE_REPO/scripts" "$FAKE_HOME"
cp "$SCRIPT" "$FAKE_REPO/scripts/check-fix-symlinks.sh"
chmod +x "$FAKE_REPO/scripts/check-fix-symlinks.sh"

if HOME="$FAKE_HOME" "$FAKE_REPO/scripts/check-fix-symlinks.sh" --fix --verbose >"$MISSING_SOURCE_OUTPUT" 2>&1; then
  printf 'expected --fix to fail when repo sources are missing\n' >&2
  exit 1
fi

assert_contains "$MISSING_SOURCE_OUTPUT" "source missing"
assert_contains "$MISSING_SOURCE_OUTPUT" "unresolved"
assert_not_exists "$FAKE_HOME/.config/nvim"

printf 'fix-links smoke test: ok\n'
