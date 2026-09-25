#!/usr/bin/env bash
# tests/pointer-follow-smoke.sh — T8a AC3 pointer_follow smoke (PLAN.md v18).
#
# Part (a) OFFLINE fixtures (always runnable, ZERO paid calls):
#   1. scripts/pointer-follow-verify over the committed fixtures in
#      tests/fixtures/token-protocol/pointer-follow/: 1 positive STRONG
#      (exit 0) + 6 negatives (each nonzero).
#   2. Lead dossier / archive oracles on FROZEN outputs: dossier-blocks.md
#      parses (REAL parser) to exactly F1+F2 with dossier.json fields, and
#      archive-plan.md carries exactly sections [Meta, Goal,
#      Acceptance Criteria].
#
# Part (b) PAID owner-path replays (REAL lead prompt over the fixed dossier
# and REAL archive template over the fixed PLAN, x 3 runs each, UNANIMOUS
# exact invariants, only for actually-deferred files) is SKIPPED: no
# deferrals are applied in T8a and paid runs are out of scope, so those
# files stand UNCLAIMED-unapplied per the master table. T8b implements
# part (b) after the T8b measure authorizes paid replays.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
FIX="$ROOT_DIR/tests/fixtures/token-protocol"
PF="$FIX/pointer-follow"
VERIFY="$ROOT_DIR/scripts/pointer-follow-verify"
PARSER="$ROOT_DIR/scripts/lib/token-finding-parser.mjs"

fail() {
  printf 'pointer-follow smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$VERIFY" ] || fail "missing $VERIFY"
[ -d "$PF" ] || fail "missing $PF"
command -v node >/dev/null 2>&1 || fail "node is required"

# ---- part (a1): validator fixtures ----
OUT="$("$VERIFY" --trace "$PF/positive-strong.json")" \
  || fail "positive STRONG fixture refused"
printf '%s\n' "$OUT" | grep -q "^STRONG" || fail "positive fixture printed no STRONG line"
echo "pointer-follow smoke: positive STRONG green"

for neg in "$PF"/negative-*.json; do
  [ -f "$neg" ] || fail "no negative fixtures in $PF"
  if "$VERIFY" --trace "$neg" >/dev/null 2>&1; then
    fail "negative fixture $(basename "$neg") wrongly accepted"
  fi
  echo "pointer-follow smoke: negative $(basename "$neg") refused as expected"
done

# ---- part (a2): lead dossier / archive oracles on frozen outputs ----
node --input-type=module -e "
import { readFileSync } from 'node:fs';
import { parseFindings } from '$PARSER';
const blocks = readFileSync('$FIX/lead-archive-fixtures/dossier-blocks.md', 'utf8');
const dossier = JSON.parse(readFileSync('$FIX/lead-archive-fixtures/dossier.json', 'utf8'));
const r = parseFindings(blocks);
if (!r.ok || r.findings.length !== 2) {
  console.error('dossier blocks do not parse to exactly 2 findings');
  process.exit(1);
}
for (let i = 0; i < 2; i++) {
  const f = r.findings[i];
  const want = dossier.findings[i];
  if (f.file !== want.file || f.line !== want.line || f.severity !== want.severity || f.issue !== want.text) {
    console.error('dossier block ' + i + ' mismatches dossier.json fields');
    process.exit(1);
  }
}
if (dossier.findings[0].disposition !== 'RETAIN' || dossier.findings[1].disposition !== 'REJECT') {
  console.error('dossier oracle is not retain-F1/reject-F2');
  process.exit(1);
}
" || fail "lead dossier oracle on frozen blocks failed"
echo "pointer-follow smoke: lead dossier oracle green (blocks == F1+F2 fields, retain-F1/reject-F2)"

SECTIONS="$(grep -E '^## ' "$FIX/lead-archive-fixtures/archive-plan.md" | sed 's/^## //')"
[ "$SECTIONS" = "$(printf 'Meta\nGoal\nAcceptance Criteria')" ] \
  || fail "archive PLAN sections are not exactly [Meta, Goal, Acceptance Criteria] (got: $SECTIONS)"
echo "pointer-follow smoke: archive oracle green (sections [Meta, Goal, Acceptance Criteria])"

echo "pointer-follow smoke: part (a) PASS (offline fixtures, zero paid calls)"
echo "pointer-follow smoke: part (b) SKIPPED — no deferrals applied, no paid replays in T8a (T8b scope)"
