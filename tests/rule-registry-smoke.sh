#!/usr/bin/env bash
# Rule-registry + router-parity pins: live census == registry rows == N,
# per-class mechanisms, and parity divergence fixtures.
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
PARITY="$ROOT_DIR/scripts/workflow-router-parity"
REGISTRY="$ROOT_DIR/workflow/runtime/rule-registry.tsv"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

EXPECTED_N=12

# --- 1. pinned live census: one perl per file, case-sensitive ---
{
  # workflow/runtime/ is machine data, excluded: the registry's own excerpts
  # would otherwise self-count in the census.
  find "$ROOT_DIR/workflow" -path "$ROOT_DIR/workflow/runtime" -prune -o -type f -print
  find "$ROOT_DIR/pi/skills" "$ROOT_DIR/claude/scopes/shared" -type f
  printf '%s\n' "$ROOT_DIR/AGENTS.md" "$ROOT_DIR/CLAUDE.md" "$ROOT_DIR/pi/AGENTS.md" "$ROOT_DIR/claude/CLAUDE.md"
} | sort >"$TMP_DIR/census-files.txt"
: >"$TMP_DIR/census-hits.txt"
while IFS= read -r f; do
  [ -f "$f" ] || fail "census scope file missing: $f"
  perl -0777 -ne 'while (/wins\s+on\s+conflict/g) { print "$ARGV\n" }' "$f" >>"$TMP_DIR/census-hits.txt"
done <"$TMP_DIR/census-files.txt"
LIVE_COUNT="$(wc -l <"$TMP_DIR/census-hits.txt" | tr -d ' ')"
[ "$LIVE_COUNT" = "$EXPECTED_N" ] || fail "live census = $LIVE_COUNT, expected $EXPECTED_N"

# --- 2. registry shape: N rows, unique ids, classed a/b ---
[ -f "$REGISTRY" ] || fail "missing $REGISTRY"
ROW_COUNT="$(tail -n +2 "$REGISTRY" | grep -c . || true)"
[ "$ROW_COUNT" = "$EXPECTED_N" ] || fail "registry rows = $ROW_COUNT, expected $EXPECTED_N"
IDS="$(tail -n +2 "$REGISTRY" | cut -f1)"
[ "$(printf '%s\n' "$IDS" | sort -u | wc -l | tr -d ' ')" = "$EXPECTED_N" ] || fail "duplicate rule ids"
while IFS="$(printf '\t')" read -r id excerpt file class mech; do
  case "$class" in
    a) [ "$mech" = "excerpt-pinned+parity:workflow-router-parity-clean" ] || fail "$id: class-a mechanism [$mech]" ;;
    b) [ "$mech" = "presence-pin:excerpt-byte-present" ] || fail "$id: class-b mechanism [$mech]" ;;
    *) fail "$id: unclassed row (class [$class])" ;;
  esac
  [ -n "$id" ] && [ -n "$excerpt" ] && [ -n "$file" ] || fail "$id: empty registry field"
done < <(tail -n +2 "$REGISTRY")

# --- 3. orphans both directions + (b) presence pins ---
sort -u "$TMP_DIR/census-hits.txt" | sed "s|^$ROOT_DIR/||" | sort >"$TMP_DIR/census-files-hit.txt"
tail -n +2 "$REGISTRY" | cut -f3 | sort -u >"$TMP_DIR/registry-files.txt"
while IFS= read -r f; do
  grep -Fxq "$f" "$TMP_DIR/registry-files.txt" || fail "orphan census hit without a row: $f"
done <"$TMP_DIR/census-files-hit.txt"
while IFS= read -r f; do
  grep -Fxq "$f" "$TMP_DIR/census-files-hit.txt" || fail "orphan row without a census hit: $f"
done <"$TMP_DIR/registry-files.txt"
pin_excerpts() {
  local root="$1" registry="$2"
  while IFS="$(printf '\t')" read -r id excerpt file class _mech; do
    grep -Fq -e "$excerpt" "$root/$file" || { printf 'PINFAIL %s\n' "$id"; return 1; }
  done < <(tail -n +2 "$registry")
}
# Every row's excerpt is presence-pinned ((a) rows: excerpt + parity;
# (b) rows: excerpt only, WEAK and labeled as such). Without the (a) pin,
# a corrupted arbitration sentence still matches the census pattern and
# parity stays green (Codex T1 C5).
pin_excerpts "$ROOT_DIR" "$REGISTRY" || fail "live excerpt pin failed"
# Corruption fixture: census pattern intact, excerpt changed -> pin fails.
CORR="$TMP_DIR/corr"
mkdir -p "$CORR/docs"
printf 'Follow the contract. The local plan wins on conflict; open it when in doubt.\n' >"$CORR/docs/a.md"
printf 'rule_id\texcerpt\tcanonical_file\tclass\tmechanism\nR1\tThe routing map `workflow/spec.md` wins on conflict\tdocs/a.md\ta\tparity:x\n' >"$CORR/reg.tsv"
if pin_excerpts "$CORR" "$CORR/reg.tsv" >/dev/null 2>&1; then
  fail "corrupted (a) excerpt should fail the pin"
fi

# --- 4. (a) mechanism: parity clean on the real tree ---
[ "$(tail -n +2 "$REGISTRY" | awk -F'\t' '$4 == "a"' | wc -l | tr -d ' ')" -gt 0 ] \
  || fail "no class-a rows to enforce"
"$PARITY" --root "$ROOT_DIR" >/dev/null 2>&1 || fail "router-parity dirty on the real tree"

# --- 5. parity fixtures: injected divergence fails, alias passes ---
mkparity() {
  local root="$1"
  mkdir -p "$root/workflow" "$root/workflow/runtime" "$root/claude/hooks" "$root/pi/extensions/lib"
  printf '# spec\n\n<!-- ROUTES:begin -->\n| Trigger | Route |\n| --- | --- |\n| T1 | `alpha` |\n| T2 | `verify` |\n<!-- ROUTES:end -->\n' >"$root/workflow/spec.md"
  printf 'export const routes = [\n  { route: "alpha" },\n  { route: "verify-workflow" },\n];\n' >"$root/workflow/runtime/workflow-router-core.mjs"
  printf '// lib\nexport * from "../../workflow/runtime/workflow-router-core.mjs";\n' >"$root/claude/hooks/workflow-router-lib.mjs"
  printf 'const r = core.route === "verify-workflow" ? "verify" : core.route;\n' >"$root/pi/extensions/lib/workflow-router-runtime.ts"
  printf 'if (d.route === "verify-workflow") return "verify";\n' >"$root/pi/extensions/lib/semantic-route.mjs"
}

P1="$TMP_DIR/p1"
mkparity "$P1"
"$PARITY" --root "$P1" >/dev/null 2>&1 || fail "parity fixture (alias) should pass"

P2="$TMP_DIR/p2"
mkparity "$P2"
python3 - "$P2/workflow/spec.md" <<'PYEOF'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
old = '<!-- ROUTES:end -->'
assert s.count(old) == 1
io.open(p, 'w', encoding='utf-8').write(s.replace(old, '| T3 | `ghost` |\n' + old))
PYEOF
if "$PARITY" --root "$P2" >"$TMP_DIR/p2.out" 2>/dev/null; then
  fail "spec-only route should fail parity"
fi
grep -Fq "spec-only route (missing from core): ghost" "$TMP_DIR/p2.out" \
  || fail "spec-only message missing"

P3="$TMP_DIR/p3"
mkparity "$P3"
printf 'export const routes = [\n  { route: "alpha" },\n  { route: "verify-workflow" },\n  { route: "rogue" },\n];\n' >"$P3/workflow/runtime/workflow-router-core.mjs"
if "$PARITY" --root "$P3" >"$TMP_DIR/p3.out" 2>/dev/null; then
  fail "core-only route should fail parity"
fi
grep -Fq "core-only route (missing from spec): rogue" "$TMP_DIR/p3.out" \
  || fail "core-only message missing"

P4="$TMP_DIR/p4"
mkparity "$P4"
printf '# spec without anchors\n\n| Trigger | Route |\n| --- | --- |\n| T1 | `alpha` |\n' >"$P4/workflow/spec.md"
if "$PARITY" --root "$P4" >"$TMP_DIR/p4.out" 2>/dev/null; then
  fail "missing anchors should fail closed"
fi
grep -Fq "0 routes extracted" "$TMP_DIR/p4.out" || fail "fail-closed message missing"

P5="$TMP_DIR/p5"
mkparity "$P5"
printf '// lib\nexport * from "../../workflow/runtime/workflow-router-core.mjs";\nconst x = { route: "local" };\n' >"$P5/claude/hooks/workflow-router-lib.mjs"
if "$PARITY" --root "$P5" >"$TMP_DIR/p5.out" 2>/dev/null; then
  fail "local lib route should fail parity"
fi
grep -Fq "local route: entries" "$TMP_DIR/p5.out" || fail "lib message missing"

P6="$TMP_DIR/p6"
mkparity "$P6"
printf '// no alias here\n' >"$P6/pi/extensions/lib/semantic-route.mjs"
if "$PARITY" --root "$P6" >"$TMP_DIR/p6.out" 2>/dev/null; then
  fail "missing pi alias line should fail parity"
fi
grep -Fq "semantic-route.mjs: no mapping line" "$TMP_DIR/p6.out" \
  || fail "pi-site message missing"

# Commented-out core routes never count as active (stripped before extract).
P7="$TMP_DIR/p7"
mkparity "$P7"
printf 'export const routes = [\n  { route: "alpha" },\n  { route: "verify-workflow" },\n  // retired: { route: "ghost" },\n  /* tombstoned { route: "phantom" } */\n];\n' >"$P7/workflow/runtime/workflow-router-core.mjs"
"$PARITY" --root "$P7" >/dev/null 2>&1 || fail "commented core routes must be ignored"
P8="$TMP_DIR/p8"
mkparity "$P8"
printf 'export const routes = [\n  { route: "alpha" },\n  // live code lost: { route: "verify-workflow" },\n];\n' >"$P8/workflow/runtime/workflow-router-core.mjs"
if "$PARITY" --root "$P8" >"$TMP_DIR/p8.out" 2>/dev/null; then
  fail "comment-only core route must not satisfy the spec"
fi
grep -Fq "spec-only route (missing from core): verify" "$TMP_DIR/p8.out" \
  || fail "comment-only message missing"

printf 'PASS: rule-registry smoke (census==rows==12, classes, parity fixtures)\n'
