#!/usr/bin/env bash
# tests/canonical-copy-smoke.sh — T8a AC2 tripwire linter (PLAN.md v18).
#
# Guards the READY-gate / check-freeze single-source rule: the canonical texts
# live in workflow/spec.md (Minimal READY gate + check-freeze); every other
# normative copy in budget-surface files + workflow/skills/* must either be a
# pointer or be listed KEPT-FOR-T8b in tests/fixtures/token-protocol/ac2-inventory.json.
#
# Structure:
#   1. self-tests on $TMPDIR fixtures (pointer-only positive passes;
#      exact-copy + rephrased-copy negatives trip; grandfather logic bites
#      both ways on synthetic inputs);
#   2. real scan: every forbidden-phrase match in scope must fall inside a
#      KEPT-FOR-T8b inventory range, and every KEPT range must still match
#      (grandfather clause: residual set EXACTLY the KEPT set — no more, no less).
#
# Out of scope (never scanned): docs/plan/ archives, ledgers (.workflow/),
# workflow/runtime/ machine data, tests/fixtures/. Canon ranges in spec.md
# (verdict=canon rows) are filtered before the comparison.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
INVENTORY="$ROOT_DIR/tests/fixtures/token-protocol/ac2-inventory.json"
BUDGET="$ROOT_DIR/workflow/runtime/context-budget.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'canonical-copy smoke: %s\n' "$1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -f "$INVENTORY" ] || fail "missing inventory: $INVENTORY"
[ -f "$BUDGET" ] || fail "missing budget: $BUDGET"

# ---- pinned forbidden phrases (normative copy tripwire) ----
# P1 hits the two long check-freeze copies (implementation-loop, contract-details);
# P2 hits the READY-gate list copy (plan-loop); P3 hits the short check-freeze
# copy (agent-quick-card). None matches the spec.md canon bodies nor the
# pointer sentences ("is canonical and wins on conflict" / "canonical list").
cat >"$TMP/phrases.txt" <<'PHRASES'
may only be strengthened or extended
A plan is `READY` only with
strengthen-only; weaken
PHRASES

# grep_matches <file> <label> >> matches.tsv (lines: "<label>\t<lineno>")
grep_matches() {
  grep -F -n -f "$TMP/phrases.txt" -- "$1" 2>/dev/null \
    | sed "s|^\([0-9][0-9]*\):.*$|$2\t\1|" || true
}

# in_scope <repo-rel-path>: reject archives, ledgers, runtime machine data, fixtures
in_scope() {
  case "$1" in
    docs/plan/* | .workflow/* | workflow/runtime/* | tests/fixtures/*) return 1 ;;
    *) return 0 ;;
  esac
}

# compare <expected.tsv> <matches.tsv> [context]
# expected lines: "<file>\t<start>\t<end>"; matches lines: "<file>\t<lineno>".
# Fails on any unexpected match (no more) or any unmatched range (no less).
compare() {
  local expected="$1" matches="$2" ctx="${3:-scan}"
  awk -F'\t' '
    FNR==NR { n=++count[$1]; rs[$1,n]=$2; re[$1,n]=$3; next }
    {
      hit=0
      for (i=1; i<=count[$1]; i++) {
        if ($2+0 >= rs[$1,i]+0 && $2+0 <= re[$1,i]+0) { hit=1; seen[$1,i]=1; break }
      }
      if (!hit) { print "unexpected: " $1 ":" $2; bad=1 }
    }
    END {
      for (f in count) for (i=1; i<=count[f]; i++)
        if (!seen[f,i]) { print "missing-range: " f ":" rs[f,i] "-" re[f,i]; bad=1 }
      exit bad ? 1 : 0
    }
  ' "$expected" "$matches" >"$TMP/compare-$ctx.out" 2>&1 || {
    fail "$ctx: grandfather mismatch: $(cat "$TMP/compare-$ctx.out" | tr '\n' '; ')"
  }
}

# drop_canon <canon.tsv> <matches.tsv> <out.tsv>: remove matches inside canon ranges
drop_canon() {
  awk -F'\t' '
    FNR==NR { n=++count[$1]; rs[$1,n]=$2; re[$1,n]=$3; next }
    {
      skip=0
      for (i=1; i<=count[$1]; i++) {
        if ($2+0 >= rs[$1,i]+0 && $2+0 <= re[$1,i]+0) { skip=1; break }
      }
      if (!skip) print
    }
  ' "$1" "$2" >"$3"
}

# ================= self-tests (fixtures in $TMPDIR only) =================

# A. pointer-only positive: pointers alone must produce ZERO matches
cat >"$TMP/pointer-only.md" <<'MD'
These hold at every step; `workflow/spec.md` § Rules is canonical and wins on
conflict.
`workflow/spec.md` § Minimal READY gate is the canonical list and wins on conflict.
A plan is `READY` when the gate in spec.md says so — see the canon.
MD
: >"$TMP/a.matches"
grep_matches "$TMP/pointer-only.md" "pointer-only.md" >>"$TMP/a.matches"
[ -s "$TMP/a.matches" ] && fail "pointer-only fixture tripped: $(cat "$TMP/a.matches")"

# B. exact-copy negative: verbatim kept-copy bytes must trip (2 phrase families)
cat >"$TMP/exact-copy.md" <<'MD'
- Check-freeze: once the plan is `READY`, its Checks and Acceptance Criteria
  may only be strengthened or extended; weakening or removing one demotes the
  plan to `CHALLENGED` with a Decision Log rationale.
A plan is `READY` only with: a clear goal; bounded scope and non-goals when
needed; concrete steps; checks to run; no blocking open question.
MD
: >"$TMP/b.matches"
grep_matches "$TMP/exact-copy.md" "exact-copy.md" >>"$TMP/b.matches"
[ "$(wc -l <"$TMP/b.matches" | tr -d ' ')" -ge 2 ] \
  || fail "exact-copy fixture should trip >=2 matches, got: $(cat "$TMP/b.matches")"

# C. rephrased-copy negative: reworded framing that keeps a pinned normative
# phrase must still trip (the tripwire pins normative phrases, not full texts)
cat >"$TMP/rephrased-copy.md" <<'MD'
Note: after READY, Checks and Acceptance Criteria may only be strengthened or extended.
Weakening one demotes the plan to `CHALLENGED` (see Decision Log).
MD
: >"$TMP/c.matches"
grep_matches "$TMP/rephrased-copy.md" "rephrased-copy.md" >>"$TMP/c.matches"
[ -s "$TMP/c.matches" ] || fail "rephrased-copy fixture did not trip"

# D. grandfather logic bites both ways (synthetic inputs, direct compare)
printf 'f.md\t10\t12\n' >"$TMP/d.expected"
printf 'f.md\t11\n' >"$TMP/d.ok"
( compare "$TMP/d.expected" "$TMP/d.ok" "selftest-d1" ) \
  || fail "self-test D1: exact synthetic set should pass"
printf 'f.md\t11\nf.md\t99\n' >"$TMP/d.extra"
( compare "$TMP/d.expected" "$TMP/d.extra" "selftest-d2" ) 2>/dev/null \
  && fail "self-test D2: extra match outside range should fail"
: >"$TMP/d.none"
( compare "$TMP/d.expected" "$TMP/d.none" "selftest-d3" ) 2>/dev/null \
  && fail "self-test D3: unmatched expected range should fail"

# E. canon filter + scope exclusions behave
printf 'workflow/spec.md\t98\t102\n' >"$TMP/e.canon"
printf 'workflow/spec.md\t99\nworkflow/other.md\t3\n' >"$TMP/e.matches"
drop_canon "$TMP/e.canon" "$TMP/e.matches" "$TMP/e.filtered"
[ "$(cat "$TMP/e.filtered")" = "workflow/other.md	3" ] \
  || fail "self-test E1: canon filter wrong: $(cat "$TMP/e.filtered")"
in_scope "workflow/skills/ship.md" || fail "self-test E2: skills file should be in scope"
in_scope "docs/plan/20260925-t8-full-draft.md" && fail "self-test E3: docs/plan must be excluded"
in_scope ".workflow/token-protocol/events.jsonl" && fail "self-test E4: ledger must be excluded"
in_scope "workflow/runtime/context-budget.json" && fail "self-test E5: runtime data must be excluded"

# ================= real scan =================

# scope = budget surface files (systematic + conditional) + workflow/skills/*
{
  jq -r '.surfaces | to_entries[] | .value.files[]?, ((.value.conditional // []) | .[].file)' "$BUDGET"
  (cd "$ROOT_DIR" && ls workflow/skills/*.md)
} | sort -u >"$TMP/scope-all.txt"

: >"$TMP/real.matches"
scope_count=0
while IFS= read -r rel; do
  in_scope "$rel" || continue
  [ -f "$ROOT_DIR/$rel" ] || fail "scope file missing: $rel"
  scope_count=$((scope_count + 1))
  grep_matches "$ROOT_DIR/$rel" "$rel" >>"$TMP/real.matches"
done <"$TMP/scope-all.txt"

jq -r '.occurrences[] | select(.verdict=="KEPT-FOR-T8b")
  | [.file] + (.line_range | split("-") | map(tonumber)) | @tsv' "$INVENTORY" >"$TMP/kept.tsv"
jq -r '.occurrences[] | select(.verdict=="canon")
  | [.file] + (.line_range | split("-") | map(tonumber)) | @tsv' "$INVENTORY" >"$TMP/canon.tsv"
[ -s "$TMP/kept.tsv" ] || fail "inventory has no KEPT-FOR-T8b rows"

drop_canon "$TMP/canon.tsv" "$TMP/real.matches" "$TMP/real.filtered"
compare "$TMP/kept.tsv" "$TMP/real.filtered" "grandfather"

kept_count="$(wc -l <"$TMP/kept.tsv" | tr -d ' ')"
match_count="$(wc -l <"$TMP/real.filtered" | tr -d ' ')"
printf 'canonical-copy smoke: ok (%s scope files, %s KEPT ranges matched by %s phrase hits, 0 unexpected)\n' \
  "$scope_count" "$kept_count" "$match_count"
