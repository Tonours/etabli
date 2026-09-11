#!/usr/bin/env bash
# Shared vendor surface policy: one source of truth for which surfaces receive
# an active vendor skill (Claude/Codex/Devin always; Pi only when pi_core).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/vendor-surfaces.sh"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'vendor surface policy smoke: %s\n' "$1" >&2
  exit 1
}

HOME_DIR="$TMP_DIR/home"
SKILL_DIR="$TMP_DIR/skill"
mkdir -p "$HOME_DIR" "$SKILL_DIR"

assert_link() {
  [ -L "$1" ] || fail "expected symlink: $1"
  [ "$(readlink "$1")" = "$SKILL_DIR" ] || fail "wrong target for $1: $(readlink "$1")"
}

assert_absent() {
  { [ ! -e "$1" ] && [ ! -L "$1" ]; } || fail "expected no link: $1"
}

# pi_core=1, active scope: linked everywhere.
vendor_link_skill_surfaces "$HOME_DIR" "$SKILL_DIR" core-skill 1 shared shared
assert_link "$HOME_DIR/.claude/skills/core-skill"
assert_link "$HOME_DIR/.codex/skills/core-skill"
assert_link "$HOME_DIR/.config/devin/skills/core-skill"
assert_link "$HOME_DIR/.pi/agent/skills/core-skill"

# pi_core=0, active scope: Pi must not receive the link.
vendor_link_skill_surfaces "$HOME_DIR" "$SKILL_DIR" shelf-skill 0 shared shared
assert_link "$HOME_DIR/.claude/skills/shelf-skill"
assert_link "$HOME_DIR/.codex/skills/shelf-skill"
assert_link "$HOME_DIR/.config/devin/skills/shelf-skill"
assert_absent "$HOME_DIR/.pi/agent/skills/shelf-skill"

# Inactive scope: linked nowhere, even with pi_core=1.
vendor_link_skill_surfaces "$HOME_DIR" "$SKILL_DIR" off-skill 1 work shared
assert_absent "$HOME_DIR/.claude/skills/off-skill"
assert_absent "$HOME_DIR/.pi/agent/skills/off-skill"

# Migration: a stale Pi link for a pi_core=0 row is pruned; expected links stay.
ln -sfn "$SKILL_DIR" "$HOME_DIR/.pi/agent/skills/shelf-skill"
vendor_prune_unexpected_skill_surfaces "$HOME_DIR" "$SKILL_DIR" shelf-skill 0 shared shared
assert_absent "$HOME_DIR/.pi/agent/skills/shelf-skill"
vendor_prune_unexpected_skill_surfaces "$HOME_DIR" "$SKILL_DIR" core-skill 1 shared shared
assert_link "$HOME_DIR/.pi/agent/skills/core-skill"

# Unrelated user symlink with a managed name is left alone.
ln -sfn "$HOME_DIR/user-target" "$HOME_DIR/.pi/agent/skills/shelf-skill"
vendor_prune_unexpected_skill_surfaces "$HOME_DIR" "$SKILL_DIR" shelf-skill 0 shared shared
[ -L "$HOME_DIR/.pi/agent/skills/shelf-skill" ] || fail "unrelated user symlink must survive prune"
rm -f "$HOME_DIR/.pi/agent/skills/shelf-skill"

# Missing scope column fails closed.
if vendor_surface_expected .claude/skills "" 1 shared; then
  fail "empty scope must fail closed"
fi

# Predicate contract.
vendor_surface_expected .pi/agent/skills shared 0 shared && fail "pi_core=0 on Pi surface must not be expected"
vendor_surface_expected .pi/agent/skills shared 1 shared || fail "pi_core=1 on Pi surface must be expected"
vendor_surface_expected .claude/skills shared 0 shared || fail "vendor skill must be expected on Claude"
vendor_surface_expected .config/devin/skills shared 0 shared || fail "vendor skill must be expected on Devin"
if vendor_surface_expected .claude/skills work 1 "shared personal"; then
  fail "inactive scope must not be expected on Claude"
fi

printf 'vendor surface policy smoke test: ok\n'
