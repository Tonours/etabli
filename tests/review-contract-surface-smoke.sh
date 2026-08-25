#!/usr/bin/env bash
set -euo pipefail

# review-contract-surface-smoke — durable CR-A discipline for the review
# contract surface (rubric + hunter templates).
#
# The .auto guard benches are session-scoped; this smoke makes the two
# invariants they protect durable at repo level (wired into
# verify-agentic-infra core — the autoresearch driver's merge gate):
#
#  1. Content budget: the union of the three surface files, counting
#     non-whitespace bytes only, stays <= CAP. Whitespace is excluded on
#     purpose: the pi-lens/markdownlint autofix churns blank lines (MD022
#     adds one after every heading) on every touch, and that formatting
#     noise must never trip the content budget — the CR-B4 leak class was
#     +1,161 B of real duty prose, which this still catches. Growing the
#     surface past CAP requires updating the recorded number here — a
#     recorded decision, not an accident.
#  2. Duty anchors: the clauses the CR-A/CR-C guards certified (concrete-
#     failure bar, severity sort with invalidity, seven-field findings,
#     deciding-code omission bar, mandatory lens rows, not-run-blocks-GO,
#     n/a artifact bar) are still present. Anchors match the pattern words
#     in order, separated by bounded non-sentence gaps (<= 120 non-period
#     chars) over newline-flattened text — tolerant of rewraps, backticks,
#     and connector words; only removal or reordering fails.

ROOT_DIR="${SURFACE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)}"
RUBRIC="$ROOT_DIR/workflow/review-rubric.md"
LOGIC="$ROOT_DIR/workflow/templates/review-logic-hunter.md"
SPEC="$ROOT_DIR/workflow/templates/review-spec-hunter.md"

# Recorded budget: 10,310 non-whitespace bytes measured 2026-08-25 (post
# CR-C1/CR-C4), with a ~3.5% working margin — same ratio the raw-byte CAP
# carried. Only non-whitespace growth counts; the CR-B4 leak class was
# +1,161 B of content and trips this with margin to spare.
CAP=10700

fail() {
  printf 'review contract surface: %s\n' "$1" >&2
  exit 1
}

for f in "$RUBRIC" "$LOGIC" "$SPEC"; do
  [ -s "$f" ] || fail "missing surface file $f"
done

nonws() { tr -d '[:space:]' <"$1" | wc -c | tr -d '[:space:]'; }
union=$(($(nonws "$RUBRIC") + $(nonws "$LOGIC") + $(nonws "$SPEC")))
[ "$union" -le "$CAP" ] ||
  fail "content union ${union}B exceeds recorded budget ${CAP}B — grow the surface deliberately (update the recorded CAP with a corpus entry), not silently"

# Gap-tolerant matcher: the pattern words must appear in order, separated
# by bounded non-sentence gaps (<= 120 non-period chars) over
# newline-flattened text.
anchor() { # <file> <pattern-words...>
  local file="$1"
  shift
  local re
  re="$(printf '%s' "$*" | sed -e 's/[.[\*^$()+?{|]/\\&/g' -e 's/ /[^.]{0,120}/g')"
  tr '\n' ' ' <"$file" | grep -Eiq "$re"
}

# --- self-validation: the gate must not trust its own matcher ------------
# Unit probes on synthetic fixtures, independent of the target tree. These
# exist because the anchor matcher once shipped joining words with '|' (OR)
# — matching any single word — and passed green. A corrupted matcher now
# fails here, before any real-tree verdict.
self_validate() {
  local d
  d="$(mktemp -d)" || fail "self-validation: mktemp failed"
  printf 'alpha beta\ngamma delta\n' >"$d/ok.txt"
  printf 'beta alpha\ndelta gamma\n' >"$d/reordered.txt"
  printf 'alpha\nbeta\ngamma\ndelta\n' >"$d/wrapped.txt"
  printf 'unrelated words entirely\n' >"$d/absent.txt"

  anchor "$d/ok.txt" alpha beta gamma delta ||
    fail "self-validation: matcher rejects an in-order clause"
  anchor "$d/wrapped.txt" alpha beta gamma delta ||
    fail "self-validation: matcher rejects a hard-wrapped clause"
  anchor "$d/reordered.txt" alpha beta gamma delta &&
    fail "self-validation: matcher accepts REORDERED words (OR-join class)"
  anchor "$d/absent.txt" alpha beta gamma delta &&
    fail "self-validation: matcher accepts an absent clause"

  # Budget counting must be whitespace-insensitive: blank-line padding
  # adds zero content bytes (MD022 churn class).
  printf 'abcdefgh' >"$d/b1.txt"
  printf 'abcd\n\n\n\ne\n\nfgh' >"$d/b2.txt"
  [ "$(tr -d '[:space:]' <"$d/b1.txt" | wc -c)" -eq 8 ] ||
    fail "self-validation: content count wrong on plain fixture"
  [ "$(tr -d '[:space:]' <"$d/b2.txt" | wc -c)" -eq 8 ] ||
    fail "self-validation: blank-line padding changed the content count"
  rm -rf "$d"
}
self_validate

# 1. Concrete-failure bar (nit bar; CR-A2/CR-A6 anchor).
anchor "$LOGIC" "a finding ships only with a concrete failure" ||
  fail "logic template lost the concrete-failure global bar"
anchor "$RUBRIC" "a finding ships only with a concrete failure" ||
  fail "rubric lost the concrete-failure global bar"

# 2. Severity sort + invalidity (CR-A7 anchor; accepts both historic
#    phrasings "Sorted by severity — high, then…" and "Findings sorted
#    high, then… (unsorted is invalid)").
anchor "$LOGIC" "sorted" "high" "medium" "low" "invalid" ||
  fail "logic template lost the severity-sort bar"
anchor "$SPEC" "sorted" "high" "medium" "low" "invalid" ||
  fail "spec template lost the severity-sort bar"

# 3. Seven-field findings discipline (CR-C4 anchor).
anchor "$LOGIC" "one line per field" "seven fields" ||
  fail "logic template lost the seven-field findings line"

# 4. Deciding-code omission bar (CR-B2 anchor, whole-template property).
anchor "$LOGIC" "empty deciding-code table" ||
  fail "logic template lost the empty-table omission bar"

# 5. Mandatory lens rows (CR-A1 anchor) and not-run-blocks-GO (CR-A4).
anchor "$RUBRIC" "Every row mandatory" ||
  fail "rubric lost the mandatory lens-row clause"
anchor "$RUBRIC" "not run" "blocks" "Verdict: GO" ||
  fail "rubric lost the not-run-blocks-GO gate"

# 6. Whole-diff n/a artifact bar (CR-B2/A3 anchor).
anchor "$RUBRIC" "whole-diff" "n/a" "document" "rename" ||
  fail "rubric lost the n/a artifact bar"
anchor "$LOGIC" "n/a" "document" "rename" ||
  fail "logic template lost the n/a artifact bar"

# 7. Emission-discipline anchors (2026-08-25 live held-out A/Bs: each pin
#    flipped a chronic harness failure 0/3 -> 3/3; nothing durable guarded
#    them until now). Files outside the CR-A union get presence anchors;
#    the lead template also gets its own recorded content budget — it grew
#    34% this session with no budget at all.
LEAD="$ROOT_DIR/workflow/templates/review-lead.md"
REVIEW_MD="$ROOT_DIR/workflow/skills/review.md"
SCAFFOLD_AGENTS="$ROOT_DIR/workflow-scaffold/templates/AGENTS.md"
for f in "$LEAD" "$REVIEW_MD" "$SCAFFOLD_AGENTS"; do
  [ -s "$f" ] || fail "missing emission-discipline file $f"
done

# lead: Status lines are bare (no bullets/backticks/bold) — the harness
# greps ^isolation: isolated$ and kin
anchor "$LEAD" "no bullets" "no backticks" "no bold" ||
  fail "lead lost the bare Status-lines pin"
# lead: colon-tight verdict prefix (French 'Verdict :' wobble guard)
anchor "$LEAD" "colon tight against the word" ||
  fail "lead lost the colon-tight Verdict pin"
# lead: machine headings survive lead assembly (re-added when dropped)
anchor "$LEAD" "re-added if a hunter omitted them" ||
  fail "lead lost the heading re-add rule"
# lead: a row that opened nothing outside the pinned diff is not run
anchor "$LEAD" "opened nothing outside the pinned diff" ||
  fail "lead lost the narrated-not-run rule"
# shared contract: routing by act-nature, not request vocabulary
anchor "$REVIEW_MD" "whatever words the request uses" ||
  fail "review.md lost the routing-by-act-nature clause"
# scaffold: ambient routing line for deployed projects
anchor "$SCAFFOLD_AGENTS" "never free-form commentary" ||
  fail "scaffold AGENTS.md lost the review routing line"

# Recorded lead content budget: 1,517 non-whitespace bytes at commit
# (2026-08-25); small working margin, same discipline as the union CAP.
LEAD_CAP=1580
lead_bytes=$(nonws "$LEAD")
[ "$lead_bytes" -le "$LEAD_CAP" ] ||
  fail "lead content ${lead_bytes}B exceeds recorded budget ${LEAD_CAP}B — grow it deliberately"

printf 'review contract surface: union %dB/%dB, lead %dB/%dB, anchors 16/16\n' "$union" "$CAP" "$lead_bytes" "$LEAD_CAP"
