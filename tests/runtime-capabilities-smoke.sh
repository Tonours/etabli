#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
MATRIX="$ROOT_DIR/workflow/runtime-capabilities.json"

# Source inspection cannot establish native support or native unavailability.
# This catches known evidence mismatches, not authenticity of free-form proofs.
check_codex_native_evidence() {
  jq -e '
    .runtimes.codex.supports_subagents as $claim |
    (($claim.proof_command | test("^(false([ #]|$)|(cat|sed|rg|grep|git show).*docs/adr/)")) or
     ($claim.proof_result | test("^Source inspection only"; "i"))) as $source_only |
    if $source_only then $claim.label == "unknown" else true end
  ' "$1" >/dev/null
}

capability_fixture="$(mktemp)"
trap 'rm -f "$capability_fixture"' EXIT
for label in confirmed blocked; do
  jq --arg label "$label" '
    .runtimes.codex.supports_subagents |=
      (.label = $label | .proof_command = "false # ADR-0015: harness removed")
  ' "$MATRIX" >"$capability_fixture"
  if check_codex_native_evidence "$capability_fixture"; then
    printf 'unsupported Codex capability fixture escaped; repair evidence-scope check\n' >&2
    exit 1
  fi
done
# A future actual probe may support confirmed; do not freeze the label unknown.
jq '.runtimes.codex.supports_subagents |=
  (.label = "confirmed" | .proof_command = "live read-only child dispatch in a Codex session" |
   .proof_result = "Synthetic fixture: child completed; not a real runtime claim")' \
  "$MATRIX" >"$capability_fixture"
check_codex_native_evidence "$capability_fixture"
check_codex_native_evidence "$MATRIX" || {
  printf 'Codex native subagent claim uses source-only evidence; record unknown or supply an appropriate runtime proof\n' >&2
  exit 1
}

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

expected_runtimes="$(printf '%s\n' claude codex grok pi | sort)"
actual_runtimes="$(jq -r '.runtimes | keys[]' "$MATRIX" | sort)"
assert_equal_sets "$expected_runtimes" "$actual_runtimes" "runtime"

expected_capabilities="$(printf '%s\n' supports_hooks supports_subagents supports_taskexecute_tracking supports_goal_state supports_structured_task_state supports_named_workflow_graphs plan_ready_mutation_guard check_freeze_guard | sort)"
for runtime in $actual_runtimes; do
  actual_capabilities="$(jq -r --arg runtime "$runtime" '.runtimes[$runtime] | keys[] | select(. != "surface_class")' "$MATRIX" | sort)"
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
  select((.value | type) == "object") |
  select((.value.proof_command // "") == "") |
  "\($runtime.key).\(.key)"
' "$MATRIX")"
if [ -n "$missing_proofs" ]; then
  printf 'missing proof_command:\n%s\n' "$missing_proofs" >&2
  exit 1
fi

missing_freshness="$(jq -r '
  .runtimes | to_entries[] as $runtime |
  $runtime.value | to_entries[] |
  select((.value | type) == "object") |
  select((.value.verified_at // "") == "" or (.value.proof_result // "") == "" or ((.value.expires_after_days // 0) <= 0)) |
  "\($runtime.key).\(.key)"
' "$MATRIX")"
if [ -n "$missing_freshness" ]; then
  printf 'missing capability freshness evidence:\n%s\n' "$missing_freshness" >&2
  exit 1
fi

stale_claims="$(jq -r --argjson now "$(date -u +%s)" '
  .runtimes | to_entries[] as $runtime |
  $runtime.value | to_entries[] |
  select((.value | type) == "object") |
  select(.value.label == "confirmed" or .value.label == "proxy_supported") |
  select((((.value.verified_at + "T00:00:00Z") | fromdateiso8601) + (.value.expires_after_days * 86400)) < $now) |
  "\($runtime.key).\(.key)"
' "$MATRIX")"
if [ -n "$stale_claims" ]; then
  printf 'stale capability claims must be re-verified or relabelled unknown:\n%s\n' "$stale_claims" >&2
  exit 1
fi

doc_labels="$(grep -Eo '`(confirmed|proxy_supported|blocked|unknown)`' "$ROOT_DIR/workflow/skills/orchestration.md" | tr -d '`' | sort -u)"
expected_labels="$(printf '%s\n' blocked confirmed proxy_supported unknown | sort)"
assert_equal_sets "$expected_labels" "$doc_labels" "label vocabulary"

printf 'runtime capabilities smoke test: ok\n'
