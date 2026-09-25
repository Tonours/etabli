#!/usr/bin/env bash
# Fixtures for scripts/workflow-adapter-sync: stamp + --check + --update-hashes.
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SYNC="$ROOT_DIR/scripts/workflow-adapter-sync"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

write_adapters() {
  local root="$1"
  mkdir -p "$root/pi/skills/demo" "$root/claude/scopes/shared/commands"
  printf -- '---\nname: demo\ndescription: Demo skill.\n---\n\n# Demo\n\nBody here.\n' >"$root/pi/skills/demo/SKILL.md"
  printf -- '---\ndescription: Demo command.\n---\n\n# Demo\n' >"$root/claude/scopes/shared/commands/demo.md"
}

write_surface() {
  local root="$1"
  printf 'demo\tpi\t1\t1\t0\nshelf\tpi\t0\t0\t0\next\tvendor\t1\t1\t0\n' >"$root/surface.tsv"
}

# Manifest with placeholder hashes; caller stamps + updates to reach clean.
write_manifest() {
  local root="$1"
  cat >"$root/manifest.json" <<'EOF'
{
  "schema_version": 1,
  "deployed": ["demo", "ext"],
  "map": {
    "demo": {"pi": "pi/skills/demo/SKILL.md", "claude": ["claude/scopes/shared/commands/demo.md"], "canonical": "pi/skills/demo/SKILL.md"},
    "ext": {"pi": null, "claude": [], "canonical": "pi/skills/ext/SKILL.md"}
  },
  "rows": [
    {"skill": "demo", "harness": "pi", "adapter": "pi/skills/demo/SKILL.md", "canonical": "pi/skills/demo/SKILL.md", "sha256": "PLACEHOLDER"},
    {"skill": "demo", "harness": "claude", "adapter": "claude/scopes/shared/commands/demo.md", "canonical": "pi/skills/demo/SKILL.md", "sha256": "PLACEHOLDER"}
  ],
  "external": [
    {"skill": "ext", "rechecked": "2026-09-25", "reason": "fixture", "evidence": []}
  ]
}
EOF
}

fresh_root() {
  local root="$1"
  mkdir -p "$root"
  write_adapters "$root"
  write_surface "$root"
  write_manifest "$root"
  "$SYNC" --root "$root" --manifest "$root/manifest.json" --surface "$root/surface.tsv" >/dev/null 2>&1 \
    || fail "fresh stamp failed for $root"
  "$SYNC" --root "$root" --manifest "$root/manifest.json" --surface "$root/surface.tsv" --update-hashes >/dev/null 2>&1 \
    || fail "fresh update-hashes failed for $root"
}

check_fails_with() {
  local root="$1" want="$2" why="$3"
  local out="$TMP_DIR/out.txt"
  if "$SYNC" --root "$root" --manifest "$root/manifest.json" --surface "$root/surface.tsv" --check >"$out" 2>/dev/null; then
    fail "$why: --check should exit 1"
  fi
  grep -Fq "$want" "$out" || { cat "$out" >&2; fail "$why: missing [$want]"; }
}

# 1. clean root passes; headers identical pointer across harnesses.
R1="$TMP_DIR/r1"
fresh_root "$R1"
"$SYNC" --root "$R1" --manifest "$R1/manifest.json" --surface "$R1/surface.tsv" --check >/dev/null 2>&1 \
  || fail "clean root should pass --check"
PI_PTR="$(grep '^pointer: ' "$R1/pi/skills/demo/SKILL.md")"
CL_PTR="$(grep '^pointer: ' "$R1/claude/scopes/shared/commands/demo.md")"
[ "$PI_PTR" = "$CL_PTR" ] || fail "pointer paragraph must be byte-identical across harnesses"
grep -q '^name: demo$' "$R1/pi/skills/demo/SKILL.md" || fail "pi block must carry name"
[ "$(grep -c '^name: ' "$R1/claude/scopes/shared/commands/demo.md")" = "0" ] \
  || fail "claude block must not carry name (description only)"

# 2. header drift: frontmatter description edited without re-stamp.
R2="$TMP_DIR/r2"
fresh_root "$R2"
python3 - "$R2/pi/skills/demo/SKILL.md" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
old = 'description: Demo skill.'
assert s.count(old) >= 1
io.open(p, 'w', encoding='utf-8').write(s.replace(old, 'description: Renamed skill.', 1))
PYEOF
check_fails_with "$R2" "header drift" "header-drift"

# 3. body tripwire, then --update-hashes rotation restores clean.
R3="$TMP_DIR/r3"
fresh_root "$R3"
printf '\nExtra body line.\n' >>"$R3/pi/skills/demo/SKILL.md"
check_fails_with "$R3" "body tripwire" "body-tripwire"
"$SYNC" --root "$R3" --manifest "$R3/manifest.json" --surface "$R3/surface.tsv" --update-hashes >/dev/null 2>&1 \
  || fail "rotation update-hashes failed"
"$SYNC" --root "$R3" --manifest "$R3/manifest.json" --surface "$R3/surface.tsv" --check >/dev/null 2>&1 \
  || fail "rotated root should pass --check"

# 4. (a) deployed skill without any row.
R4="$TMP_DIR/r4"
fresh_root "$R4"
printf 'demo\tpi\t1\t1\t0\nshelf\tpi\t0\t0\t0\next\tvendor\t1\t1\t0\nnorow\tpi\t1\t0\t0\n' >"$R4/surface.tsv"
jq '.deployed += ["norow"] | .map.norow = {"pi": null, "claude": [], "canonical": "pi/skills/norow/SKILL.md"}' \
  "$R4/manifest.json" >"$R4/m.json" && mv "$R4/m.json" "$R4/manifest.json"
check_fails_with "$R4" "(a) deployed skill without a manifest row" "missing-row"

# 5. (c) row for an undeployed skill.
R5="$TMP_DIR/r5"
fresh_root "$R5"
mkdir -p "$R5/pi/skills/shelf"
printf -- '---\nname: shelf\ndescription: Shelf skill.\n---\n\n# Shelf\n' >"$R5/pi/skills/shelf/SKILL.md"
jq '.rows += [{"skill": "shelf", "harness": "pi", "adapter": "pi/skills/shelf/SKILL.md", "canonical": "pi/skills/shelf/SKILL.md", "sha256": "PLACEHOLDER"}] | .map.shelf = {"pi": "pi/skills/shelf/SKILL.md", "claude": [], "canonical": "pi/skills/shelf/SKILL.md"}' \
  "$R5/manifest.json" >"$R5/m.json" && mv "$R5/m.json" "$R5/manifest.json"
check_fails_with "$R5" "(c) stale row for an undeployed skill" "stale-row"

# 6. (d) stamped file without a row (row deleted after stamp).
R6="$TMP_DIR/r6"
fresh_root "$R6"
jq '.rows |= map(select(.adapter != "claude/scopes/shared/commands/demo.md")) | .map.demo.claude = []' \
  "$R6/manifest.json" >"$R6/m.json" && mv "$R6/m.json" "$R6/manifest.json"
check_fails_with "$R6" "(d) stamped adapter file without a manifest row" "unrowed-stamped"

# 7. (d) same-name unstamped file for a deployed skill without a row.
R7="$TMP_DIR/r7"
fresh_root "$R7"
mkdir -p "$R7/pi/skills/demo2"
printf -- '---\nname: demo2\ndescription: Demo two.\n---\n\n# Demo2\n' >"$R7/pi/skills/demo2/SKILL.md"
printf 'demo\tpi\t1\t1\t0\nshelf\tpi\t0\t0\t0\next\tvendor\t1\t1\t0\ndemo2\tpi\t1\t0\t0\n' >"$R7/surface.tsv"
jq '.deployed += ["demo2"] | .map.demo2 = {"pi": null, "claude": [], "canonical": "pi/skills/demo2/SKILL.md"}' \
  "$R7/manifest.json" >"$R7/m.json" && mv "$R7/m.json" "$R7/manifest.json"
check_fails_with "$R7" "(d) same-name adapter file for deployed skill [demo2] without a row" "unrowed-samename"

# 8. (b) row file vanished.
R8="$TMP_DIR/r8"
fresh_root "$R8"
rm "$R8/claude/scopes/shared/commands/demo.md"
check_fails_with "$R8" "(b) row file vanished" "vanished"

# 9. external without recency.
R9="$TMP_DIR/r9"
fresh_root "$R9"
jq '.external[0] |= del(.rechecked)' "$R9/manifest.json" >"$R9/m.json" && mv "$R9/m.json" "$R9/manifest.json"
check_fails_with "$R9" "exemption without recency" "external-recency"

# 10. external violated by an appearing in-repo file.
R10="$TMP_DIR/r10"
fresh_root "$R10"
mkdir -p "$R10/pi/skills/ext"
printf -- '---\nname: ext\ndescription: Ext.\n---\n\n# Ext\n' >"$R10/pi/skills/ext/SKILL.md"
check_fails_with "$R10" "exemption violated" "external-violated"

# 11. manifest deployed set drifted from the surface.
R11="$TMP_DIR/r11"
fresh_root "$R11"
jq '.deployed = ["demo"]' "$R11/manifest.json" >"$R11/m.json" && mv "$R11/m.json" "$R11/manifest.json"
check_fails_with "$R11" "deployed set drifted" "deployed-drift"

# 12. map path without a row.
R12="$TMP_DIR/r12"
fresh_root "$R12"
jq '.map.demo.claude += ["claude/scopes/shared/commands/ghost.md"]' "$R12/manifest.json" >"$R12/m.json" && mv "$R12/m.json" "$R12/manifest.json"
check_fails_with "$R12" "map path without a row" "map-closure"

printf 'PASS: adapter-sync smoke (stamp/check/rotate/lifecycle fixtures)\n'
