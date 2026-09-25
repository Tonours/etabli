#!/usr/bin/env bash
# Codex source-measure gate (T7 AC3, FULL profile): hermetic fixture homes
# exercise the check logic (pass under cap, FAIL on breach, folded + plain
# multi-line descriptions measured in full, dangling SKILL.md warns without
# failing, vendor .system/ excluded from the gated total); Case 5 gates the
# real repo-deployed vendor surface (union of scopes) so description growth
# fails CI. The live $HOME number (6536/8000 at implement) stays recorded
# evidence, not a CI assertion (machine-owned links vary).
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/codex-skill-source-check"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

write_skill() {
  local dir="$1" body="$2"
  mkdir -p "$dir"
  printf '%s\n' "$body" >"$dir/SKILL.md"
}

# Case 1: under cap (2 small skills + folded description + .system vendor).
HOME1="$TMP_DIR/home1"
mkdir -p "$HOME1/.codex/skills"
write_skill "$HOME1/.codex/skills/alpha" '---
name: alpha
description: First fixture skill.
---
body'
write_skill "$HOME1/.codex/skills/beta" '---
name: beta
description: >
  Folded fixture description spanning
  two lines, measured in full.
---
body'
write_skill "$HOME1/.codex/skills/.system/vendor-owned" '---
name: vendor-owned
description: Vendor bytes never count toward the repo gate.
---
body'
OUT1="$("$CHECK" --home "$HOME1" 2>&1)" || fail "under-cap fixture failed: $OUT1"
printf '%s\n' "$OUT1" | grep -q 'skills=2' || fail "expected skills=2: $OUT1"
printf '%s\n' "$OUT1" | grep -q 'system_skills=1' || fail "expected system_skills=1: $OUT1"
# alpha 5+20+20=45; beta 4+64+20=88 → 133 total (folded in full).
printf '%s\n' "$OUT1" | grep -q 'source_chars=133 ' || fail "folded mis-measured: $OUT1"
printf '%s\n' "$OUT1" | grep -q 'codex-skill-source-check: ok' || fail "missing ok: $OUT1"

# Case 2: breach fails with the remedy ladder.
HOME2="$TMP_DIR/home2"
mkdir -p "$HOME2/.codex/skills"
BIG_DESC="$(python3 -c 'print("x" * 8100)')"
write_skill "$HOME2/.codex/skills/hog" "---
name: hog
description: $BIG_DESC
---
body"
OUT2="$("$CHECK" --home "$HOME2" 2>&1)" && fail "breach fixture passed (cap not enforced)"
printf '%s\n' "$OUT2" | grep -q 'FAIL: X1' || fail "breach lacks X1: $OUT2"
printf '%s\n' "$OUT2" | grep -q 'remedy ladder' || fail "breach lacks ladder: $OUT2"

# Case 3: dangling SKILL.md warns but exits 0 (zero-char rot, not a breach).
HOME3="$TMP_DIR/home3"
mkdir -p "$HOME3/.codex/skills/ghost" "$HOME3/.codex/skills/live"
ln -s "$TMP_DIR/nowhere/SKILL.md" "$HOME3/.codex/skills/ghost/SKILL.md"
write_skill "$HOME3/.codex/skills/live" '---
name: live
description: Lone live skill.
---
body'
OUT3="$("$CHECK" --home "$HOME3" 2>&1)" || fail "dangling fixture failed: $OUT3"
printf '%s\n' "$OUT3" | grep -q 'WARN: dangling SKILL.md: ghost' || fail "missing dangling warn: $OUT3"
printf '%s\n' "$OUT3" | grep -q 'skills=1' || fail "dangling skill counted: $OUT3"

# Case 4: plain multi-line description measured in full (R3-B2: first-line
# only under-measured an 8100-char fixture at 37, sailing past the gate).
HOME4="$TMP_DIR/home4"
mkdir -p "$HOME4/.codex/skills"
write_skill "$HOME4/.codex/skills/plain" '---
name: plain
description: First line of a plain scalar
  continued on an indented second line
  and a third.
---
body'
OUT4="$("$CHECK" --home "$HOME4" 2>&1)" || fail "plain-multiline fixture failed: $OUT4"
# plain 5 + 78 (3 lines joined) + 20 = 103.
printf '%s\n' "$OUT4" | grep -q 'source_chars=103 ' || fail "plain continuation mis-measured: $OUT4"

# Case 5: repo-deployed surface (R3-B3) — materialize the installer-linked
# vendor skills from the repo catalog (union of all scopes: deterministic
# in CI, covers real description growth on every machine) and gate them.
# Fixtures above cover edge logic; this covers the real bytes.
. "$ROOT_DIR/scripts/lib/skill-catalog.sh"
HOME5="$TMP_DIR/home5"
mkdir -p "$HOME5/.codex/skills"
while IFS="$(printf '\t')" read -r v_name v_dir v_pi_core v_vendor; do
  [ -n "$v_name" ] || continue
  [ -d "$v_dir" ] || fail "catalog vendor skill dir missing: $v_dir"
  ln -s "$v_dir" "$HOME5/.codex/skills/$v_name"
done < <(skill_catalog_active_vendor_records "$ROOT_DIR/workflow/runtime/skill-surface.tsv" "$ROOT_DIR" "shared work personal")
[ -n "$(ls -A "$HOME5/.codex/skills")" ] || fail "repo-deployed surface empty (catalog read failed?)"
OUT5="$("$CHECK" --home "$HOME5" 2>&1)" || fail "repo-deployed codex surface breached the gate: $OUT5"

printf 'PASS: codex-skill-source (under-cap + breach-fail + dangling-warn + vendor-excluded + plain-multiline + repo-surface %s)\n' "$(printf '%s' "$OUT5" | head -1)"
