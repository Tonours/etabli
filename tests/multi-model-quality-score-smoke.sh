#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

node "$SCRIPT_DIR/multi-model-real-smoke.mjs" --self-test

# Portfolio A live pins must stay present in the real smoke harness.
if ! grep -Fq 'model: "gpt-5.5"' "$SCRIPT_DIR/multi-model-real-smoke.mjs"; then
  printf 'multi-model quality score smoke: expected gpt-5.5 coordinator/baseline pin\n' >&2
  exit 1
fi
if ! grep -Fq 'model: "gpt-5.6-sol"' "$SCRIPT_DIR/multi-model-real-smoke.mjs"; then
  printf 'multi-model quality score smoke: expected gpt-5.6-sol ceiling pin\n' >&2
  exit 1
fi
if ! grep -Fq 'deepseek-v4-flash' "$SCRIPT_DIR/multi-model-real-smoke.mjs"; then
  printf 'multi-model quality score smoke: expected deepseek-v4-flash scout pin\n' >&2
  exit 1
fi

jq -e '
  .version == 1 and
  (.fixtures | length) == 3 and
  all(.fixtures[];
    (has("expected") | not) and
    (.catalog | length) == 5 and
    (.source | length) > 0
  )
' "$SCRIPT_DIR/fixtures/multi-model-quality/agent-fixtures.json" >/dev/null

jq -e '
  .version == 1 and
  (.fixtures | length) == 3 and
  all(.fixtures[];
    (has("source") | not) and
    (has("catalog") | not) and
    (.expected | length) == 3
  )
' "$SCRIPT_DIR/fixtures/multi-model-quality/score-key.json" >/dev/null

jq -s -e '
  (.[0].fixtures | map(.id) | sort) == (.[1].fixtures | map(.id) | sort)
' \
  "$SCRIPT_DIR/fixtures/multi-model-quality/agent-fixtures.json" \
  "$SCRIPT_DIR/fixtures/multi-model-quality/score-key.json" >/dev/null

printf 'multi-model quality score smoke: ok\n'
