#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/deploy-agent-workflow"

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
  local dir="$1" name="$2"
  mkdir -p "$dir"
  printf -- '---\nname: %s\ndescription: fixture\n---\nbody\n' "$name" >"$dir/SKILL.md"
}

REPO="$TMP_DIR/repo"
HOME_DIR="$TMP_DIR/home"
CATALOG="$REPO/catalog.tsv"
mkdir -p "$REPO/vendor/suiteA/skills" "$REPO/vendor/suiteB/skills" "$REPO/pi/skills" \
  "$HOME_DIR/.pi/agent/skills" "$HOME_DIR/.claude/skills" "$HOME_DIR/.codex/skills" "$HOME_DIR/.agents/skills"

write_skill "$REPO/vendor/suiteA/skills/alpha" alpha
write_skill "$REPO/vendor/suiteA/skills/beta" beta
write_skill "$REPO/vendor/suiteB/skills/gamma" gamma
write_skill "$REPO/pi/skills/core-one" core-one

printf 'suiteA\thttps://example.invalid/a.git\tmain\tshared\talpha,beta\nsuiteB\thttps://example.invalid/b.git\tmain\tshared\tgamma\n' >"$REPO/vendor/sources.tsv"

write_catalog() {
  {
    printf '# fixture catalog\n'
    printf 'core-one\tpi\t1\t1\t1\n'
    printf 'alpha\tsuiteA\t1\t0\t1\n'
    printf 'beta\tsuiteA\t0\t0\t1\n'
    printf 'gamma\tsuiteB\t1\t0\t1\n'
  } >"$CATALOG"
}
write_catalog

run_deploy() {
  REPO_DIR="$REPO" SKILL_CATALOG="$CATALOG" HOME_DIR="$HOME_DIR" DRY_RUN=0 ACTIVE_SCOPES="shared" deploy_vendor_skills
}

link_count() {
  local surface="$1" name="$2"
  [ -L "$HOME_DIR/$surface/$name" ] && echo 1 || echo 0
}

run_deploy

[ "$(link_count .pi/agent/skills alpha)" = 1 ] || fail "pi_core=1 vendor skill alpha missing on pi"
[ "$(link_count .claude/skills alpha)" = 1 ] || fail "active vendor skill alpha missing on claude"
[ "$(link_count .pi/agent/skills beta)" = 0 ] || fail "pi_core=0 vendor skill beta must not link on pi"
[ "$(link_count .claude/skills beta)" = 1 ] || fail "active vendor skill beta missing on claude"

mkdir -p "$TMP_DIR/foreign/suiteB/skills/gamma" "$TMP_DIR/foreign/suiteA/skills/beta"
write_skill "$TMP_DIR/foreign/suiteB/skills/gamma" gamma
write_skill "$TMP_DIR/foreign/suiteA/skills/beta" beta
ln -s "$TMP_DIR/foreign/suiteB/skills/gamma" "$HOME_DIR/.pi/agent/skills/gamma"
ln -s "$TMP_DIR/foreign/suiteA/skills/beta" "$HOME_DIR/.pi/agent/skills/beta"
run_deploy
[ "$(readlink "$HOME_DIR/.pi/agent/skills/gamma")" = "$REPO/vendor/suiteB/skills/gamma" ] || fail "foreign-checkout gamma was not converged to the repo vendor target"
[ ! -L "$HOME_DIR/.pi/agent/skills/beta" ] || fail "foreign-checkout pi_core=0 vendor link beta survived convergence"
[ -L "$HOME_DIR/.claude/skills/gamma" ] || fail "repo-vendor gamma missing on claude after foreign prune"

ln -s "$HOME_DIR/.agents/skills/nothing-there" "$HOME_DIR/.pi/agent/skills/ghost-mirror"
run_deploy
[ ! -L "$HOME_DIR/.pi/agent/skills/ghost-mirror" ] || fail "broken cross-surface mirror survived prune"

grep -v '^gamma' "$CATALOG" >"$CATALOG.tmp" && mv "$CATALOG.tmp" "$CATALOG"
run_deploy
for surface in .pi/agent/skills .claude/skills .codex/skills .agents/skills; do
  [ ! -L "$HOME_DIR/$surface/gamma" ] || fail "orphan vendor link gamma remains in $surface after row removal"
done
[ -d "$REPO/vendor/suiteB/skills/gamma" ] || fail "row removal must keep the vendor tree"

ln -s "$REPO/vendor/suiteB/skills/gamma" "$HOME_DIR/.pi/agent/skills/gamma"
ln -s "$REPO/vendor/suiteB/skills/gamma" "$HOME_DIR/.claude/skills/gamma"
rm -rf "$REPO/vendor/suiteB"
run_deploy
for surface in .pi/agent/skills .claude/skills .codex/skills .agents/skills; do
  [ ! -L "$HOME_DIR/$surface/gamma" ] || fail "dangling gamma link remains in $surface after row+tree removal"
done
for surface in .pi/agent/skills .claude/skills .codex/skills .agents/skills; do
  for link in "$HOME_DIR/$surface"/*; do
    [ -e "$link" ] || [ -L "$link" ] || continue
    [ -e "$link" ] || fail "dangling link $link remains in $surface after row+tree removal"
  done
done

printf 'PASS: vendor prune modes (gating, foreign checkout, mirror, orphan, row+tree)\n'
