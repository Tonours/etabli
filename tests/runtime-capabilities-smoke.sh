#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
MATRIX="$ROOT_DIR/workflow/runtime-capabilities.json"

assert_equal_sets() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if ! diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"); then
    printf '%s set mismatch\n' "$label" >&2
    exit 1
  fi
}

jq empty "$MATRIX"

expected_runtimes="$(printf '%s\n' claude codex pi | sort)"
actual_runtimes="$(jq -r '.runtimes | keys[]' "$MATRIX" | sort)"
assert_equal_sets "$expected_runtimes" "$actual_runtimes" "runtime"

expected_capabilities="$(printf '%s\n' supports_hooks supports_subagents supports_goal_state supports_structured_task_state | sort)"
for runtime in $actual_runtimes; do
  actual_capabilities="$(jq -r --arg runtime "$runtime" '.runtimes[$runtime] | keys[]' "$MATRIX" | sort)"
  assert_equal_sets "$expected_capabilities" "$actual_capabilities" "$runtime capability"
done

bad_labels="$(jq -r '.. | objects | select(has("label")) | .label | select(. != "confirmed" and . != "proxy_supported" and . != "blocked" and . != "unknown")' "$MATRIX")"
if [ -n "$bad_labels" ]; then
  printf 'invalid labels:\n%s\n' "$bad_labels" >&2
  exit 1
fi

missing_proofs="$(jq -r '
  .runtimes | to_entries[] as $runtime |
  $runtime.value | to_entries[] |
  select((.value.proof_command // "") == "") |
  "\($runtime.key).\(.key)"
' "$MATRIX")"
if [ -n "$missing_proofs" ]; then
  printf 'missing proof_command:\n%s\n' "$missing_proofs" >&2
  exit 1
fi

doc_labels="$(grep -Eo '`(confirmed|proxy_supported|blocked|unknown)`' "$ROOT_DIR/workflow/skills/orchestration.md" | tr -d '`' | sort -u)"
expected_labels="$(printf '%s\n' blocked confirmed proxy_supported unknown | sort)"
assert_equal_sets "$expected_labels" "$doc_labels" "label vocabulary"

printf 'runtime capabilities smoke test: ok\n'
