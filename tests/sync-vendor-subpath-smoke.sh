#!/usr/bin/env bash
set -euo pipefail

# Hermetic smoke for the optional subpath column in scripts/sync-vendor-skills.
# Builds local fixture git repos (no network): one upstream with skills under a
# subpath, one legacy upstream with skills at the repo root, and a scratch
# consumer repo that runs the real script.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SYNC="$ROOT_DIR/scripts/sync-vendor-skills"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local text="$1" needle="$2"
  case "$text" in
    *"$needle"*) ;;
    *) fail "expected output to contain '$needle', got: $text" ;;
  esac
}

# --- fixture upstream A: skills under a subpath -----------------------------
up_sub="$TMP_DIR/upstream-sub"
git -C "$TMP_DIR" init -q -b main upstream-sub
mkdir -p "$up_sub/monorepo/plugins/mystack/skills/how" \
         "$up_sub/monorepo/plugins/mystack/skills/why"
printf -- '---\nname: how\ndescription: subpath fixture\n---\nbody how\n' \
  >"$up_sub/monorepo/plugins/mystack/skills/how/SKILL.md"
printf -- '---\nname: why\ndescription: subpath fixture\n---\nbody why\n' \
  >"$up_sub/monorepo/plugins/mystack/skills/why/SKILL.md"
printf 'MIT fixture license (subpath)\n' >"$up_sub/monorepo/plugins/mystack/LICENSE"
printf 'DIFFERENT root license that must not mix in\n' >"$up_sub/LICENSE.md"
git -C "$up_sub" add -A
git -C "$up_sub" -c user.email=f@f -c user.name=f commit -qm fixture

# --- fixture upstream B: legacy layout, skills at repo root -----------------
up_root="$TMP_DIR/upstream-root"
git -C "$TMP_DIR" init -q -b main upstream-root
mkdir -p "$up_root/skills/solo"
printf -- '---\nname: solo\ndescription: root fixture\n---\nbody solo\n' \
  >"$up_root/skills/solo/SKILL.md"
printf 'MIT fixture license\n' >"$up_root/LICENSE.md"
git -C "$up_root" add -A
git -C "$up_root" -c user.email=f@f -c user.name=f commit -qm fixture

# --- scratch consumer repo running the real script --------------------------
consumer="$TMP_DIR/consumer"
git -C "$TMP_DIR" init -q -b main consumer
mkdir -p "$consumer/scripts" "$consumer/vendor"
cp "$SYNC" "$consumer/scripts/sync-vendor-skills"
printf '# vendor\trepo\tref\tscope\tskills\tsubpath\n' \
  >"$consumer/vendor/sources.tsv"
printf 'mystack\t%s\tmain\tshared\thow,why\tmonorepo/plugins/mystack\n' \
  "$up_sub" >>"$consumer/vendor/sources.tsv"
printf 'legacy\t%s\tmain\tshared\tsolo\t\n' "$up_root" >>"$consumer/vendor/sources.tsv"
git -C "$consumer" add -A
git -C "$consumer" -c user.email=f@f -c user.name=f commit -qm fixture

out="$("$consumer/scripts/sync-vendor-skills" mystack)"
assert_contains "$out" "2 skills at"
[ -d "$consumer/vendor/mystack/skills/how" ] || fail "subpath skill how missing"
[ -d "$consumer/vendor/mystack/skills/why" ] || fail "subpath skill why missing"
[ -f "$consumer/vendor/mystack/UPSTREAM_SHA" ] || fail "subpath UPSTREAM_SHA missing"
[ -f "$consumer/vendor/mystack/LICENSE" ] || fail "subpath LICENSE not copied"
grep -q "subpath)" "$consumer/vendor/mystack/LICENSE" ||
  fail "LICENSE must come from the subpath, not the repo root"
[ ! -e "$consumer/vendor/mystack/LICENSE.md" ] ||
  fail "root LICENSE.md must not mix in when the subpath ships its own license"
sha="$(cat "$consumer/vendor/mystack/UPSTREAM_SHA")"
if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  fail "UPSTREAM_SHA must be a 40-hex commit id, got: $sha"
fi
git -C "$up_sub" rev-parse --verify --quiet "$sha" >/dev/null ||
  fail "UPSTREAM_SHA does not resolve in the fixture upstream"

out="$("$consumer/scripts/sync-vendor-skills" legacy)"
assert_contains "$out" "1 skills at"
[ -d "$consumer/vendor/legacy/skills/solo" ] || fail "legacy skill solo missing"
[ -f "$consumer/vendor/legacy/LICENSE.md" ] || fail "legacy LICENSE.md not copied"

# --- dirty-tree refusal still holds (tracked modification) ------------------
git -C "$consumer" add -A
git -C "$consumer" -c user.email=f@f -c user.name=f commit -qm "vendor state"
printf 'dirty\n' >>"$consumer/vendor/legacy/skills/solo/SKILL.md"
if "$consumer/scripts/sync-vendor-skills" legacy >/dev/null 2>&1; then
  fail "sync must refuse a dirty vendor tree"
fi
status="$(cd "$consumer" && git status --porcelain vendor/legacy)"
assert_contains "$status" "M "

git -C "$consumer" checkout -- vendor/legacy/skills/solo/SKILL.md

# --- missing subpath skill fails closed -------------------------------------
printf 'missing\t%s\tmain\tshared\thow,absent\tmonorepo/plugins/mystack\n' \
  "$up_sub" >>"$consumer/vendor/sources.tsv"
git -C "$consumer" add -A
git -C "$consumer" -c user.email=f@f -c user.name=f \
  commit -qm "add missing-skill row" >/dev/null

if "$consumer/scripts/sync-vendor-skills" missing >/dev/null 2>&1; then
  fail "sync must fail closed when a subpath skill is absent upstream"
fi

printf 'PASS: sync-vendor-skills subpath smoke\n'
