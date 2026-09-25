#!/usr/bin/env bash
# tests/hunter-parity-smoke.sh — T8a AC4 parity oracle smoke (PLAN.md v18).
#
# Part (a) OFFLINE fixtures (always runnable, ZERO paid calls): the economic
# parity predicate (scripts/token-task-report --check-parity, every output
# through the REAL finding parser) over $TMPDIR artifact sets — one valid
# economic set (6 patches x 2 variants, Frozen Canned Blocks byte-exact +
# `No findings.` cleans) plus the 5 refusal sets — and one direct parser
# assertion on the pinned pp-null-deref block.
#
# Part (b) economic-artifacts replay (unanimous per-patch predicate on both
# variants x 3 runs + agreement over the T8b campaign artifacts) is SKIPPED:
# the economic campaign is NONRUN in T8a (no econ artifacts exist), so
# parity-NONRUN flows to AC4 UNCLAIMED per the master table. T8b implements
# part (b) against its campaign artifacts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
FIX="$ROOT_DIR/tests/fixtures/token-protocol"
MANIFEST="$FIX/parity-manifest.json"
REPORT="$ROOT_DIR/scripts/token-task-report"
PARSER="$ROOT_DIR/scripts/lib/token-finding-parser.mjs"

fail() {
  printf 'hunter-parity smoke: %s\n' "$1" >&2
  exit 1
}

[ -f "$MANIFEST" ] || fail "missing $MANIFEST"
[ -x "$REPORT" ] || fail "missing $REPORT"
command -v node >/dev/null 2>&1 || fail "node is required"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- part (a1): direct parser assertion on the pinned pp-null-deref block ----
node --input-type=module -e "
import { readFileSync } from 'node:fs';
import { parseFindings } from '$PARSER';
const block = [
  'severity: high',
  'file: users.js',
  'line: 3',
  'issue: null guard missing on getUser(id).name dereference',
  'impact: TypeError crash on null return',
  'review_comment: caller contract requires a null check',
  'suggested_fix: Add a null guard before dereferencing.',
].join('\n');
const r = parseFindings(block);
if (!r.ok || r.findings.length !== 1 || r.findings[0].file !== 'users.js' || r.findings[0].line !== 3) {
  console.error('pinned pp-null-deref block does not parse with file+line');
  process.exit(1);
}
const clean = parseFindings('No findings.');
if (!clean.ok || clean.findings.length !== 0) {
  console.error('No findings. does not yield zero findings');
  process.exit(1);
}
if (parseFindings('severity: high\nfile: x').ok) {
  console.error('unparseable output wrongly accepted');
  process.exit(1);
}
" || fail "direct parser assertions failed"
echo "hunter-parity smoke: parser assertions green (pinned block + No-findings + unparseable)"

# ---- part (a2): parity predicate over $TMPDIR artifact sets ----
node --input-type=module -e "
import { mkdirSync, writeFileSync } from 'node:fs';
const TMP = '$TMP';
const BLOCKS = {
  'pp-null-deref': [
    'severity: high',
    'file: users.js',
    'line: 3',
    'issue: null guard missing on getUser(id).name dereference',
    'impact: TypeError crash on null return',
    'review_comment: caller contract requires a null check',
    'suggested_fix: Add a null guard before dereferencing.',
  ].join('\n'),
  'pp-off-by-one': [
    'severity: high',
    'file: list.js',
    'line: 2',
    'issue: off-by-one past end reads items[items.length]',
    'impact: undefined index yields undefined',
    'review_comment: last valid index is length - 1',
    'suggested_fix: Index items[items.length - 1] instead.',
  ].join('\n'),
  'pp-swallowed-error': [
    'severity: high',
    'file: loader.js',
    'line: 4',
    'issue: empty catch swallows error and returns null',
    'impact: callers expecting throw-on-missing receive null',
    'review_comment: module contract is throw on missing file',
    'suggested_fix: Remove the empty catch or rethrow.',
  ].join('\n'),
};
const CLEAN = 'No findings.';
const PATCHES = ['pp-null-deref', 'pp-off-by-one', 'pp-swallowed-error', 'pp-clean-1', 'pp-clean-2', 'pp-clean-3'];
const outputFor = (id) => BLOCKS[id] ?? CLEAN;
const usage = { in: 100, out: 50, cr: 0, cc: 0 };
function writeSet(name, mutate) {
  const dir = TMP + '/' + name;
  mkdirSync(dir, { recursive: true });
  const runs = [];
  for (const variant of ['baseline', 'candidate']) {
    for (const id of PATCHES) {
      runs.push({ task_id: id, variant, run: 1, verdict: 'pass', usage: { ...usage }, output: outputFor(id) });
    }
  }
  if (mutate) mutate(runs);
  writeFileSync(dir + '/flow.json', JSON.stringify({ flow: 'economic' }) + '\n');
  writeFileSync(dir + '/runs.json', JSON.stringify({ schema_version: 1, seed: 7, runs }, null, 2) + '\n');
}
writeSet('valid', null);
writeSet('finding-on-clean', (runs) => {
  runs.find((r) => r.task_id === 'pp-clean-1' && r.variant === 'baseline').output = BLOCKS['pp-null-deref'];
});
writeSet('regex-mismatch', (runs) => {
  const row = runs.find((r) => r.task_id === 'pp-null-deref' && r.variant === 'candidate');
  row.output = BLOCKS['pp-null-deref'].replace(
    'issue: null guard missing on getUser(id).name dereference',
    'issue: rename displayName to getDisplayName for style consistency',
  ).replace('impact: TypeError crash on null return', 'impact: none, purely cosmetic')
   .replace('review_comment: caller contract requires a null check', 'review_comment: style only')
   .replace('suggested_fix: Add a null guard before dereferencing.', 'suggested_fix: Rename in a style pass.');
});
writeSet('variant-disagreement', (runs) => {
  runs.find((r) => r.task_id === 'pp-off-by-one' && r.variant === 'candidate').output = CLEAN;
});
writeSet('malformed-block', (runs) => {
  runs.find((r) => r.task_id === 'pp-swallowed-error' && r.variant === 'baseline').output = 'severity: high\nfile: loader.js';
});
writeSet('wrong-patch-attribution', (runs) => {
  runs.find((r) => r.task_id === 'pp-off-by-one' && r.variant === 'baseline').output = BLOCKS['pp-null-deref'];
});
" || fail "could not generate parity fixture sets"

"$REPORT" --artifacts "$TMP/valid" --expect-flow economic \
  --check-parity --manifest "$MANIFEST" >$TMP/valid.log 2>&1 \
  || fail "valid economic set refused (see $TMP/valid.log)"
grep -q "parity: 6/6 patches pass, variants agree" $TMP/valid.log \
  || fail "valid set missed the parity line"
grep -q "baseline: 150 tokens/task, \$0.0002/task, 0.0" $TMP/valid.log \
  || fail "valid set missed the pinned {150, \$0.0002, 0.0} baseline line"
grep -q "candidate: 150 tokens/task, \$0.0002/task, 0.0" $TMP/valid.log \
  || fail "valid set missed the pinned {150, \$0.0002, 0.0} candidate line"
echo "hunter-parity smoke: valid economic set green (parity 6/6 + pinned numbers)"

for neg in finding-on-clean regex-mismatch variant-disagreement malformed-block wrong-patch-attribution; do
  if "$REPORT" --artifacts "$TMP/$neg" --expect-flow economic \
      --check-parity --manifest "$MANIFEST" >/dev/null 2>&1; then
    fail "negative set $neg wrongly accepted"
  fi
  echo "hunter-parity smoke: negative $neg refused as expected"
done

# Cross-flow isolation: economic artifacts under a screening expectation refuse.
if "$REPORT" --artifacts "$TMP/valid" --expect-flow screening >/dev/null 2>&1; then
  fail "cross-flow feed (economic as screening) wrongly accepted"
fi
echo "hunter-parity smoke: cross-flow feed refused as expected"

echo "hunter-parity smoke: part (a) PASS (offline fixtures, zero paid calls)"
echo "hunter-parity smoke: part (b) SKIPPED — economic campaign NONRUN, no econ artifacts exist (T8b scope)"
