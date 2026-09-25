#!/usr/bin/env bash
# Fixtures for scripts/workflow-ledger-check: boundary policy + live run.
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/workflow-ledger-check"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

WF="$TMP_DIR/wf"
mkdir -p "$WF/valid-run"
# valid-run: single canonical route_decided
printf '%s\n' '{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"route_decided","run":"valid-run","detail":{"route":"answer","reason":"smoke"}}' >"$WF/valid-run/events.jsonl"
# new-drift: unknown type, not inventoried
printf '%s\n' '{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"ship_complete","run":"new-drift","detail":{}}' >"$WF/new-drift-tmp"
mkdir -p "$WF/new-drift" && mv "$WF/new-drift-tmp" "$WF/new-drift/events.jsonl"
# terminal-drift: terminal but invalid history, not inventoried (H5 boundary)
mkdir -p "$WF/terminal-drift"
printf '%s\n' '{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"review_completed","run":"terminal-drift","detail":{"status":"pass","evidence":"x"}}' '{"schema_version":2,"ts":"2026-01-01T00:00:01Z","event":"completed","run":"terminal-drift","detail":{"summary":"done"}}' >"$WF/terminal-drift/events.jsonl"
# quarantined: invalid, inventoried with matching sha
mkdir -p "$WF/quarantined"
printf '%s\n' '{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"ship_complete","run":"quarantined","detail":{}}' >"$WF/quarantined/events.jsonl"
# stale-valid: valid ledger listed in inventory
printf '%s\n' '{"schema_version":2,"ts":"2026-01-01T00:00:00Z","event":"route_decided","run":"stale-valid","detail":{"route":"answer","reason":"smoke"}}' >"$WF/stale-valid-tmp"
mkdir -p "$WF/stale-valid" && mv "$WF/stale-valid-tmp" "$WF/stale-valid/events.jsonl"

sha_of() { shasum -a 256 "$1" | awk '{print $1}'; }
Q_SHA="$(sha_of "$WF/quarantined/events.jsonl")"
S_SHA="$(sha_of "$WF/stale-valid/events.jsonl")"
INV="$TMP_DIR/inventory.json"
printf '{"version":1,"frozen":"2026-01-01T00:00:00Z","entries":[{"slug":"quarantined","sha256":"%s","reason":"smoke"},{"slug":"stale-valid","sha256":"%s","reason":"smoke-stale"},{"slug":"gone-ledger","sha256":"abc","reason":"smoke-gone"}],"amendments":[]}' "$Q_SHA" "$S_SHA" >"$INV"

# a. valid-only dir passes
ONLY="$TMP_DIR/only"
mkdir -p "$ONLY/valid-run" && cp "$WF/valid-run/events.jsonl" "$ONLY/valid-run/"
printf '{"version":1,"entries":[],"amendments":[]}' >"$TMP_DIR/empty-inv.json"
"$CHECK" --dir "$ONLY" --inventory "$TMP_DIR/empty-inv.json" >/dev/null || fail "valid ledger must pass (empty inventory)"

# b. new drift fails
if "$CHECK" --dir "$WF" --inventory "$TMP_DIR/empty-inv.json" >"$TMP_DIR/out.txt" 2>&1; then
  fail "uninventoried drift must fail"
fi
grep -q "new-drift: new drift" "$TMP_DIR/out.txt" || fail "new drift not named"

# e. terminal-but-invalid uninventoried fails too
grep -q "terminal-drift: new drift" "$TMP_DIR/out.txt" || fail "terminal drift must fail when uninventoried"

# c+f+g. inventoried quarantined warns (exit 0), stale warns
mkdir -p "$TMP_DIR/wf2/quarantined" "$TMP_DIR/wf2/stale-valid"
cp "$WF/quarantined/events.jsonl" "$TMP_DIR/wf2/quarantined/"
cp "$WF/stale-valid/events.jsonl" "$TMP_DIR/wf2/stale-valid/"
if ! "$CHECK" --dir "$TMP_DIR/wf2" --inventory "$INV" >"$TMP_DIR/out2.txt" 2>&1; then
  fail "inventoried drift must warn, not fail"
fi
grep -q "WARN quarantined drift: quarantined" "$TMP_DIR/out2.txt" || fail "quarantine warn missing"
grep -q "WARN stale inventory entry (ledger valid again, remove it): stale-valid" "$TMP_DIR/out2.txt" || fail "stale-valid warn missing"
grep -q "WARN stale inventory entry (ledger gone): gone-ledger" "$TMP_DIR/out2.txt" || fail "gone-ledger warn missing"

# d. quarantined content changed fails
printf '%s\n' '{"schema_version":2,"ts":"2026-01-01T00:00:01Z","event":"ship_complete","run":"quarantined","detail":{}}' >>"$TMP_DIR/wf2/quarantined/events.jsonl"
if "$CHECK" --dir "$TMP_DIR/wf2" --inventory "$INV" --full >"$TMP_DIR/out3.txt" 2>&1; then
  fail "changed quarantined ledger must fail"
fi
grep -q "changed since freeze" "$TMP_DIR/out3.txt" || fail "freeze-change not named"

# k. warm-cache quarantine does not survive inventory removal (L1).
KW="$TMP_DIR/kw"
mkdir -p "$KW/bad" && cp "$WF/quarantined/events.jsonl" "$KW/bad/"
printf '{"version":1,"entries":[{"slug":"bad","sha256":"%s","reason":"k"}],"amendments":[]}' "$(sha_of "$KW/bad/events.jsonl")" >"$TMP_DIR/k-inv.json"
"$CHECK" --dir "$KW" --inventory "$TMP_DIR/k-inv.json" >/dev/null || fail "k setup must warn"
printf '{"version":1,"entries":[],"amendments":[]}' >"$TMP_DIR/k-inv.json"
if "$CHECK" --dir "$KW" --inventory "$TMP_DIR/k-inv.json" >"$TMP_DIR/outk.txt" 2>&1; then
  fail "removed pin must fail even with warm cache"
fi
grep -q "bad: new drift" "$TMP_DIR/outk.txt" || fail "removed pin must report new drift"

# l. stale cache under a rotated validator is not trusted (T2-HIGH-1).
LW="$TMP_DIR/lw"
mkdir -p "$LW/bad" && cp "$WF/quarantined/events.jsonl" "$LW/bad/"
printf '{"version":1,"validator":"%s","validated":{"bad":"%s"}}' \
  "0000000000000000000000000000000000000000000000000000000000000000" \
  "$(sha_of "$LW/bad/events.jsonl")" >"$LW/.ledger-check-cache.json"
if "$CHECK" --dir "$LW" --inventory "$TMP_DIR/empty-inv.json" >"$TMP_DIR/outl.txt" 2>&1; then
  fail "stale OK under rotated validator must fail"
fi
grep -q "bad: new drift" "$TMP_DIR/outl.txt" || fail "stale OK must report new drift"

# h+i. skips
"$CHECK" --dir "$TMP_DIR/nope" >"$TMP_DIR/skip1.txt" || fail "missing dir must SKIP"
grep -q "SKIP" "$TMP_DIR/skip1.txt" || fail "missing-dir SKIP unexplained"
"$CHECK" --dir "$ONLY" --workflow-event "$TMP_DIR/nope-bin" >"$TMP_DIR/skip2.txt" || fail "missing CLI must SKIP"
grep -q "SKIP" "$TMP_DIR/skip2.txt" || fail "missing-CLI SKIP unexplained"

# cache file created
[ -f "$TMP_DIR/wf2/.ledger-check-cache.json" ] || fail "cache file not created"

# j. live repo run stays green
"$CHECK" >/dev/null || fail "live ledger check must pass post-cleanup"

printf 'PASS: workflow-ledger-check fixture + live assertions\n'
