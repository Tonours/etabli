#!/usr/bin/env bash
# Tranche 5 ship-order pins: /ship step order (thermo + cumulative review
# BEFORE push, sweep closed content), budget transfer, archive hash control,
# delta rule, metrics registry lifecycle, F12 per-harness matrix, and census
# behaviour. (Vocabulary + profiles live in workflow-event-smoke.sh.)
# Prose side is pinned by anchored grep; mechanics execute in tmp trees.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SHIP="$ROOT_DIR/workflow/skills/ship.md"
LOOP="$ROOT_DIR/workflow/skills/implementation-loop.md"
ADV="$ROOT_DIR/workflow/skills/adversary.md"
EVENTS="$ROOT_DIR/workflow/events.md"
EVENT_BIN="$ROOT_DIR/scripts/workflow-event"
CENSUS_BIN="$ROOT_DIR/scripts/workflow-ledger-census"
METRICS_BIN="$ROOT_DIR/scripts/workflow-ship-metrics"

fail() { printf 'ship-order: %s\n' "$1" >&2; exit 1; }
assert_contains() { grep -qF "$2" "$1" || fail "missing [$2] in $1"; }
assert_count() { [ "$(grep -cF "$2" "$1")" = "$3" ] || fail "expected $3 [$2] in $1"; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ship-order.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# AC2: step order 4 pre-commit < 5 thermo < 6 cumulative < 7 sweep.
step4=$(grep -n '^4\. Pre-commit pass' "$SHIP" | cut -d: -f1)
step5=$(grep -n '^5\. \*\*Thermo' "$SHIP" | cut -d: -f1)
step6=$(grep -n '^6\. \*\*Cumulative review gate' "$SHIP" | cut -d: -f1)
step7=$(grep -n '^7\. Final sweep commit' "$SHIP" | cut -d: -f1)
[ -n "$step4" ] && [ -n "$step5" ] && [ -n "$step6" ] && [ -n "$step7" ] \
  || fail "ship steps 4-7 headings not found"
[ "$step4" -lt "$step5" ] && [ "$step5" -lt "$step6" ] && [ "$step6" -lt "$step7" ] \
  || fail "ship steps out of order: 4=$step4 5=$step5 6=$step6 7=$step7"

# AC2: single shared counter + archive hash control.
assert_contains "$SHIP" '"consumed":{"T":'
assert_contains "$SHIP" 'SAME T/D/F counter'
assert_contains "$SHIP" 'next unspent F round'
assert_contains "$SHIP" 'review budget transferred'
assert_contains "$SHIP" 'remaining = {2,2,2}'
assert_contains "$SHIP" 'archive_commit'
assert_contains "$SHIP" 'git show'
assert_contains "$SHIP" 'divergence → `blocked`'

# AC4/B1: ship ledger slug sanitization + collision rule.
assert_contains "$SHIP" 'lowercased with `/` replaced'
assert_contains "$SHIP" 'ship-feat-abc-123-x'
assert_contains "$SHIP" 'suffix `-2`, `-3`'

# AC1: bounded machine the ship counter is transferred from.
assert_contains "$LOOP" 'T1: findings → fold → T2'
assert_contains "$LOOP" 'F2 (always on the delivery SHA'
assert_contains "$LOOP" 'are POSITIONAL'
assert_contains "$LOOP" 'tour tag `FD`'
assert_contains "$LOOP" 'FD never routes to F1 or D2'
assert_contains "$LOOP" 'adversary only if a high-severity finding was'
assert_contains "$ADV" 'D rounds add the adversary only if a high-severity finding was'
assert_contains "$LOOP" 'exhausted D budget at F1'
assert_contains "$LOOP" 'abandoned on scratch'
assert_contains "$LOOP" 'T exhausted'
assert_contains "$LOOP" 'no post-F1 T re-entry'
assert_contains "$LOOP" 'Mechanical enforcement of this machine is tranche 6'

# AC3: delta rule — ancestry + two-dot + 50-line heuristic + surfaces.
assert_contains "$SHIP" 'merge-base --is-ancestor'
assert_contains "$SHIP" 'git diff --numstat -z <reviewed-sha>'
assert_count "$SHIP" 'numstat -z' '3'
assert_contains "$SHIP" 'delta > 50'
assert_contains "$SHIP" 'review-metrics.md'
assert_contains "$SHIP" 'canonical `jq -S` parsed'
assert_contains "$SHIP" 'Negative pin: a lone changed'
assert_contains "$SHIP" 'git status --porcelain'
assert_contains "$SHIP" 'fails to parse (unreadable output)'

# AC5: registry + aggregate lifecycle.
assert_contains "$SHIP" 'run=<slug> | 0 | 0 | 0 |'
assert_contains "$SHIP" 'ship-metrics/<run-slug>.json'
assert_contains "$SHIP" 'under `flock`'
assert_contains "$SHIP" 'never a second row'

# AC6: F12 per-harness matrix (partial, porting is T7).
assert_contains "$SHIP" 'no-ai-slop-detect'
assert_contains "$SHIP" 'Pi — prose only'
assert_contains "$SHIP" 'Claude — prose only'
assert_contains "$SHIP" 'detect mode'
assert_contains "$SHIP" '`pr_body_style` by chain'
assert_contains "$SHIP" 'T7 entry criterion'

# AC4: terminal definition + success shorthand (no bare "folded").
assert_contains "$EVENTS" 'THEN final'
assert_contains "$EVENTS" 'findings:<n>-folded'
assert_contains "$SHIP" 'not-reached:<step>` mapping'
assert_contains "$SHIP" '`thermo_nuclear` → step 5'
assert_contains "$SHIP" '`delta_rereview` → step 11'
assert_contains "$SHIP" 'git ls-tree <archive_commit>'
assert_contains "$SHIP" "No \`route_decided\`: \`ship\` is not a route"

# AC5/AC10: CI segments share one clock and one attempt budget (r2 reads r1).
assert_contains "$SHIP" 'ci-fix-<PR>-r<n>'
assert_contains "$SHIP" "t0 = first segment's first ts"
assert_contains "$SHIP" 'attempts exhausted → refuse'

# --- Archive hash control executes: committed bytes, not worktree bytes.
ARCH="$TMP_ROOT/archrepo"
git init -q "$ARCH"
git -C "$ARCH" config user.email 'smoke@test'
git -C "$ARCH" config user.name 'smoke'
printf 'archive v1\n' > "$ARCH/plan.md"
git -C "$ARCH" add plan.md
git -C "$ARCH" commit -qm 'archive'
capture="$(shasum -a 256 "$ARCH/plan.md" | cut -d' ' -f1)"
check="$(git -C "$ARCH" show HEAD:plan.md | shasum -a 256 | cut -d' ' -f1)"
[ "$capture" = "$check" ] || fail 'archive hash recheck mismatch on clean tree'
printf 'tampered\n' > "$ARCH/plan.md"
recheck="$(git -C "$ARCH" show HEAD:plan.md | shasum -a 256 | cut -d' ' -f1)"
[ "$recheck" = "$capture" ] || fail 'archive recheck must read committed bytes'

# --- Registry: roundtrip + schema reject + 2-writer concurrency, 0 lost update.
WF="$TMP_ROOT/wf"
"$METRICS_BIN" --dir "$WF" upsert conc '{"verdict":"unmeasured"}' >/dev/null
[ "$(ls "$WF/ship-metrics" | grep -c '\.json$')" = "1" ] || fail 'registry must hold one row file'
writer() {
  local tag="$1" i
  for i in $(seq 1 25); do
    "$METRICS_BIN" --dir "$WF" upsert conc "{\"buckets\":{\"${tag}_${i}\":true}}" >/dev/null
  done
}
writer a & writer b &
wait
keys="$(jq -r '.buckets | keys | length' "$WF/ship-metrics/conc.json")"
[ "$keys" = "50" ] || fail "concurrency lost updates: $keys/50 bucket keys"
jq -e '.run_slug == "conc" and .verdict == "unmeasured"' "$WF/ship-metrics/conc.json" >/dev/null \
  || fail 'registry row corrupted by concurrent writers'
if "$METRICS_BIN" --dir "$WF" upsert conc '{"models":"nope"}' >/dev/null 2>&1; then
  fail 'registry accepted a mistyped models field'
fi
# escaped_later is a count (summed by escaped_per_go), never a boolean.
"$METRICS_BIN" --dir "$WF" upsert conc '{"escaped_later":2,"pr_url":"https://example.test/pr/9"}' >/dev/null
jq -e '.escaped_later == 2' "$WF/ship-metrics/conc.json" >/dev/null \
  || fail 'registry did not store numeric escaped_later'
if "$METRICS_BIN" --dir "$WF" upsert conc '{"escaped_later":true}' >/dev/null 2>&1; then
  fail 'registry accepted boolean escaped_later'
fi
# find-pr resolves the single row carrying a PR URL (mini-PR updates).
[ "$("$METRICS_BIN" --dir "$WF" find-pr 'https://example.test/pr/9')" = "conc" ] \
  || fail 'find-pr did not resolve the row by PR URL'
if "$METRICS_BIN" --dir "$WF" find-pr 'https://example.test/pr/missing' >/dev/null 2>&1; then
  fail 'find-pr resolved an unknown PR URL'
fi
# Post-cleanup conservation: the registry lives at the invocation root,
# not in the removable worktree.
mkdir -p "$TMP_ROOT/root/wt"
"$METRICS_BIN" --dir "$TMP_ROOT/root/.workflow" upsert kept '{"verdict":"go"}' >/dev/null
rm -rf "$TMP_ROOT/root/wt"
"$METRICS_BIN" --dir "$TMP_ROOT/root/.workflow" show kept >/dev/null \
  || fail 'registry row did not survive worktree cleanup'

# Ship vocab/profile/legacy fixtures live in tests/workflow-event-smoke.sh
# (Tranche 5 block, per PLAN Checks); only the AC2 transfer carrier stays
# here, next to the order/transfer prose pins.
LED="$TMP_ROOT/ledgers"
# Transfer carrier (H3): a file_changed detail carrying the budget record
# validates — the prose shape is executable, not aspirational.
"$EVENT_BIN" --dir "$LED" append ship-xfer file_changed '{"path":"loop-dir","change":"review budget transferred","loop_ledger":"loop","loop_head_sha":"abc","consumed":{"T":2,"D":0,"F":1},"remaining":{"T":0,"D":2,"F":1}}' >/dev/null
"$EVENT_BIN" --dir "$LED" validate ship-xfer >/dev/null \
  || fail 'transfer carrier file_changed rejected'
# --- Census tmp fixtures: growth is listed, flip/missing fail.
CEN="$TMP_ROOT/census"
mkledger() {
  "$EVENT_BIN" --dir "$CEN" append "$1" file_changed '{"path":"f","change":"c"}' >/dev/null
  "$EVENT_BIN" --dir "$CEN" append "$1" validation_run '{"command":"c","exit":0}' >/dev/null
  "$EVENT_BIN" --dir "$CEN" append "$1" outcome_metric '{"outcome":"o","success":true,"measured":false,"reason":"smoke"}' >/dev/null
}
mkledger cen-stable
mkledger cen-grow
mkledger cen-gone
"$EVENT_BIN" --dir "$CEN" append cen-stable completed '{"summary":"done"}' >/dev/null
"$EVENT_BIN" --dir "$CEN" append cen-gone completed '{"summary":"done"}' >/dev/null
"$CENSUS_BIN" --dir "$CEN" baseline "$TMP_ROOT/base.tsv" >/dev/null
# Clean growth: open ledger appends valid events → CROISSANCE, exit 0.
"$EVENT_BIN" --dir "$CEN" append cen-grow file_changed '{"path":"g","change":"more"}' >/dev/null
"$EVENT_BIN" --dir "$CEN" append cen-grow validation_run '{"command":"c","exit":0}' >/dev/null
growth_out="$("$CENSUS_BIN" --dir "$CEN" diff "$TMP_ROOT/base.tsv")" \
  || fail 'census diff failed on clean growth'
printf '%s\n' "$growth_out" | grep -q "^CROISSANCE	cen-grow	OK" \
  || fail "census missed CROISSANCE: $growth_out"
printf '%s\n' "$growth_out" | grep -q 'FLIP' && fail "census reported FLIP on clean growth: $growth_out" || true
# Flip + missing + added → exit nonzero with all three kinds.
mkledger cen-new
rm -rf "$CEN/cen-gone"
printf 'not json\n' >> "$CEN/cen-stable/events.jsonl"
if flip_out="$("$CENSUS_BIN" --dir "$CEN" diff "$TMP_ROOT/base.tsv" 2>&1)"; then
  fail 'census diff passed with a flip and a missing slug'
fi
printf '%s\n' "$flip_out" | grep -q "^AJOUTÉ	cen-new	OK" || fail "census missed AJOUTÉ: $flip_out"
printf '%s\n' "$flip_out" | grep -q "^MANQUANT	cen-gone" || fail "census missed MANQUANT: $flip_out"
printf '%s\n' "$flip_out" | grep -q "^FLIP	cen-stable	OK" || fail "census missed FLIP: $flip_out"
# M8a: same verdict but non-append-only bytes → REWRITE, exit nonzero.
CEN2="$TMP_ROOT/census2"
"$EVENT_BIN" --dir "$CEN2" append cen-rw file_changed '{"path":"f","change":"c"}' >/dev/null
"$EVENT_BIN" --dir "$CEN2" append cen-rw validation_run '{"command":"c","exit":0}' >/dev/null
"$CENSUS_BIN" --dir "$CEN2" baseline "$TMP_ROOT/base2.tsv" >/dev/null
printf '{"schema_version":2,"ts":"2026-09-24T00:00:01Z","event":"file_changed","run":"cen-rw","detail":{"path":"zzz","change":"rewritten"}}\n' > "$CEN2/cen-rw/events.jsonl"
printf '{"schema_version":2,"ts":"2026-09-24T00:00:02Z","event":"validation_run","run":"cen-rw","detail":{"command":"c","exit":0}}\n' >> "$CEN2/cen-rw/events.jsonl"
"$EVENT_BIN" --dir "$CEN2" validate cen-rw >/dev/null || fail 'rewrite fixture does not validate'
if rewrite_out="$("$CENSUS_BIN" --dir "$CEN2" diff "$TMP_ROOT/base2.tsv" 2>&1)"; then
  fail 'census diff passed on a rewritten ledger'
fi
printf '%s\n' "$rewrite_out" | grep -q "^REWRITE	cen-rw	OK" || fail "census missed REWRITE: $rewrite_out"
# C5: a grandfathered byte-string reappearing under an unknown slug fails.
CEN3="$TMP_ROOT/census3"
mkdir -p "$CEN3/cen-ghost"
printf 'not json\n' > "$CEN3/cen-ghost/events.jsonl"
ghost_sha="$(shasum -a 256 "$CEN3/cen-ghost/events.jsonl" | cut -d' ' -f1)"
printf '{"entries":[{"slug":"cen-ghost","sha256":"%s"}]}\n' "$ghost_sha" > "$TMP_ROOT/pins.json"
: > "$TMP_ROOT/base3.tsv"
if ghost_out="$(CENSUS_PINS_FILE="$TMP_ROOT/pins.json" "$CENSUS_BIN" --dir "$CEN3" diff "$TMP_ROOT/base3.tsv" 2>&1)"; then
  fail 'census diff passed on an AJOUTÉ QUAR'
fi
printf '%s\n' "$ghost_out" | grep -q "^AJOUTÉ	cen-ghost	QUAR" || fail "census missed AJOUTÉ QUAR: $ghost_out"
# C3: hash portability + fail-hard (no silent empty SHA).
. "$ROOT_DIR/scripts/lib/hash.sh"
[ "$(hash256 "$CEN2/cen-rw/events.jsonl" | cut -d' ' -f1)" = "$(shasum -a 256 "$CEN2/cen-rw/events.jsonl" | cut -d' ' -f1)" ] \
  || fail 'hash256 disagrees with shasum'
CEN4="$TMP_ROOT/census4"
mkdir -p "$CEN4/cen-dark"
printf '{}\n' > "$CEN4/cen-dark/events.jsonl"
chmod 000 "$CEN4/cen-dark/events.jsonl"
if "$CENSUS_BIN" --dir "$CEN4" baseline "$TMP_ROOT/base4.tsv" >/dev/null 2>&1; then
  fail 'census baseline passed on an unreadable ledger'
fi
chmod 644 "$CEN4/cen-dark/events.jsonl"

printf 'ship-order: ok\n'
