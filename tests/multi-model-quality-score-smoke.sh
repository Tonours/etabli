#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

node "$SCRIPT_DIR/multi-model-real-smoke.mjs" --self-test

# Live parents must stay on the managed portfolio (no retired gpt-5.6-* pins).
if grep -E 'model:[[:space:]]*"gpt-5\.6' "$SCRIPT_DIR/multi-model-real-smoke.mjs" >/dev/null; then
  printf 'multi-model quality score smoke: retired openai-codex/gpt-5.6-* pin still present\n' >&2
  exit 1
fi
if ! grep -Fq 'model: "gpt-5.5"' "$SCRIPT_DIR/multi-model-real-smoke.mjs"; then
  printf 'multi-model quality score smoke: expected gpt-5.5 coordinator/baseline pin\n' >&2
  exit 1
fi
if ! grep -Fq 'model: "k3"' "$SCRIPT_DIR/multi-model-real-smoke.mjs"; then
  printf 'multi-model quality score smoke: expected kimi-coding/k3 ceiling pin\n' >&2
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
