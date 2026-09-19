#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JUDGE="$ROOT/scripts/jev-judge"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

health="$(env -u TYPESAFE_API_KEY "$JUDGE" health)"
jq -e '.ok == true and .profiles == 12 and .credential == "absent" and .live_by_default == false' <<<"$health" >/dev/null

profiles="$("$JUDGE" list)"
jq -e '.profiles | length == 12' <<<"$profiles" >/dev/null
jq -e '[.profiles[].id] | index("skill-suggestion") != null and index("task-state-fallback") != null' <<<"$profiles" >/dev/null

"$JUDGE" show claim-evidence | jq -e '.authority == "advisory" and (.questions | keys | length == 2)' >/dev/null

printf '%s\n' '{"text":"bounded goal","structured_state_available":false}' >"$TMP/state.json"
if "$JUDGE" evaluate task-state-fallback --state-file "$TMP/state.json" >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: evaluate succeeded without --live" >&2
  exit 1
fi
grep -q 'requires explicit --live' "$TMP/err"

env -u TYPESAFE_API_KEY "$JUDGE" evaluate task-state-fallback --state-file "$TMP/state.json" --live --no-receipt |
  jq -e '.outcome == "abstain" and .error_code == "missing_api_key"' >/dev/null

ln -s "$TMP/state.json" "$TMP/state-link.json"
if env -u TYPESAFE_API_KEY "$JUDGE" evaluate task-state-fallback --state-file "$TMP/state-link.json" --live --no-receipt >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: accepted symlink input" >&2
  exit 1
fi
grep -q 'regular non-symlink file' "$TMP/err"

printf '%s\n' 'bounded evidence' >"$TMP/evidence.txt"
printf '| Claim | Evidence | Status |\n| --- | --- | --- |\n| Bounded claim | %s | verified |\n' "$TMP/evidence.txt" >"$TMP/claims.md"
env -u TYPESAFE_API_KEY "$JUDGE" evaluate-claim --claims-file "$TMP/claims.md" --claim-index 0 --live --no-receipt |
  jq -e '.outcome == "abstain" and .error_code == "missing_api_key"' >/dev/null

if env -u TYPESAFE_API_KEY "$JUDGE" evaluate-claim --claims-file "$TMP/claims.md" --live --no-receipt >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: accepted a missing claim index" >&2
  exit 1
fi
grep -q 'claim index must be an explicit non-negative integer' "$TMP/err"

printf '%s\n' '| Claim | Evidence | Status |' '| --- | --- | --- |' '| Invalid claim | /definitely/missing/evidence | verified |' >"$TMP/bad-claims.md"
if env -u TYPESAFE_API_KEY "$JUDGE" evaluate-claim --claims-file "$TMP/bad-claims.md" --claim-index 0 --live --no-receipt >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: accepted structurally invalid claim" >&2
  exit 1
fi
grep -q 'structural check failed' "$TMP/err"

grep -q 'install_script "jev-judge"' "$ROOT/scripts/lib/install-main.sh"
grep -q 'check_script_link "jev-judge"' "$ROOT/scripts/check-fix-symlinks.sh"

"$ROOT/scripts/jev-profile-calibrate" validate --all |
  jq -e '.ok == true and (.profiles | length == 12) and ([.profiles[].semantic_cases] | all(. == 12))' >/dev/null
"$ROOT/scripts/jev-profile-calibrate" dry-run-budget --all --repetitions 3 --max-attempts 600 --max-input-tokens 1500000 --max-seconds 1500 |
  jq -e '.ok == true and .computed_max_attempts == 468 and .request_reservation_tokens == 64000' >/dev/null

echo "jev-judge-smoke: ok"
