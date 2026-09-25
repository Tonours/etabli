#!/usr/bin/env bash
# Trigger-eval gate (T7 AC2b, FULL profile): recompute the majority reduction
# from committed raw runs, verify it matches the committed results, then run
# skill-eval compare. No provider calls: model runs happen at implement and
# on demand; CI only re-verifies. A pre-reduced boolean is never trusted.
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EV="$ROOT_DIR/tests/fixtures/skill-trigger-eval"
MANIFEST="$ROOT_DIR/workflow/self-improvement/manifests/trigger-descriptions-v1.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

[ -f "$MANIFEST" ] || fail "missing trigger eval manifest"
for side in baseline candidate; do
  [ -d "$EV/$side" ] || fail "missing committed $side raw runs"
  # 3-RUN REDUCTION PINNED (AC2/R4): the reducer accepts >=2 runs, so the
  # gate enforces exactly the 3 committed runs + _meta (a partial dir from
  # a dead runner must fail here, never silently reduce).
  for f in run1.json run2.json run3.json _meta.json; do
    [ -f "$EV/$side/$f" ] || fail "committed $side raw runs incomplete (missing $f)"
  done
  [ "$(ls "$EV/$side"/run*.json | wc -l | tr -d ' ')" = "3" ] \
    || fail "committed $side raw runs must hold exactly 3 run files"
  # Pinned probe model (runner PINNED_MODEL): a hand-swapped model or
  # temperature must fail here, not silently re-verify.
  META_OK="$(python3 -c "
import json
m = json.load(open('$EV/$side/_meta.json'))
print('ok' if m.get('model') == 'qwen/qwen3-8b' and m.get('temperature') == 0 and m.get('runs') == 3 else 'BAD:' + json.dumps(m))
")"
  [ "$META_OK" = "ok" ] || fail "committed $side _meta not pinned ($META_OK)"
  "$ROOT_DIR/scripts/skill-trigger-reduce" --raw "$EV/$side" --corpus "$EV/corpus.json" \
    --manifest "$MANIFEST" --evaluator-root "$ROOT_DIR" --out "$TMP_DIR/$side.json" >/dev/null 2>&1 \
    || fail "reduction failed for $side"
  cmp -s "$TMP_DIR/$side.json" "$EV/$side.json" \
    || fail "committed $side.json differs from recomputed reduction (re-run the eval, never hand-edit)"
done

# Negative: a hand-corrupted record (response_raw: null — never
# runner-written) must tamper-fail the reduction, never silently score
# (R3-B1: untyped records forged a false held_in gain + false accepted).
NEG_DIR="$TMP_DIR/neg"
mkdir -p "$NEG_DIR"
cp "$EV/baseline"/run1.json "$EV/baseline"/run2.json "$EV/baseline"/run3.json "$EV/baseline"/_meta.json "$NEG_DIR/"
python3 - "$NEG_DIR/run1.json" <<'PY' || fail "negative fixture setup crashed"
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["records"][0]["response_raw"] = None
d["records"][0]["response_norm"] = ""
d["records"][0]["passed"] = False
json.dump(d, open(p, "w"))
PY
if "$ROOT_DIR/scripts/skill-trigger-reduce" --raw "$NEG_DIR" --corpus "$EV/corpus.json" \
  --manifest "$MANIFEST" --evaluator-root "$ROOT_DIR" --out "$TMP_DIR/neg.json" >/dev/null 2>&1; then
  fail "reduction accepted a null response_raw (R3-B1 tamper hole)"
fi

if command -v bun >/dev/null 2>&1; then
  RUN="bun $ROOT_DIR/scripts/lib/skill-eval.mjs"
  JS="bun"
  TEST_SUB="test"
else
  RUN="node $ROOT_DIR/scripts/lib/skill-eval.mjs"
  JS="node"
  TEST_SUB="--test"
fi
# Unit safety for the eval's own moving parts (shared normalize + ceiling
# rule reference vectors) before trusting them below.
"$JS" "$TEST_SUB" "$ROOT_DIR/tests/skill-trigger-normalize.test.mjs" >/dev/null 2>&1 \
  || fail "normalize reference vectors failed"
"$JS" "$TEST_SUB" "$ROOT_DIR/tests/skill-trigger-ceiling.test.mjs" >/dev/null 2>&1 \
  || fail "ceiling reference vectors failed"
# shellcheck disable=SC2086
$RUN compare --manifest "$MANIFEST" --baseline "$TMP_DIR/baseline.json" \
  --candidate "$TMP_DIR/candidate.json" --baseline-artifact "$EV/baseline" \
  --candidate-artifact "$EV/candidate" --evaluator-root "$ROOT_DIR" >"$TMP_DIR/verdict.json" 2>/dev/null \
  || [ -s "$TMP_DIR/verdict.json" ] \
  || fail "skill-eval compare crashed without a verdict"
# The bar itself lives in scripts/lib/skill-eval-ceiling.mjs (named rule +
# reference vectors); the smoke only orchestrates and reports its path.
CLAUSE_OK="$("$JS" --input-type=module -e "
import { readFileSync } from 'node:fs';
import { ceilingBarResult } from '$ROOT_DIR/scripts/lib/skill-eval-ceiling.mjs';
const v = JSON.parse(readFileSync('$TMP_DIR/verdict.json', 'utf8'));
const r = ceilingBarResult(v);
console.log(r.path + (r.path === 'reject' ? ':' + r.detail : ''));
" 2>/dev/null || echo "error")"
case "$CLAUSE_OK" in
  accepted) printf 'PASS: skill-trigger-eval (recomputed reduction + compare accepted)\n' ;;
  ceiling) printf 'PASS: skill-trigger-eval (recomputed reduction + ceiling clause HOLD 12/12, zero regressions)\n' ;;
  *) fail "trigger eval bar not met ($CLAUSE_OK, see recomputed verdict)" ;;
esac
