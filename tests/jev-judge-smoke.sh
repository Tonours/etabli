#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JUDGE="$ROOT/scripts/jev-judge"

"$JUDGE" health --no-retry | jq -e '.max_retries == 0' >/dev/null ||
  fail "health --no-retry must expose an effective zero-retry policy"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

health="$(env -u TYPESAFE_API_KEY "$JUDGE" health)"
jq -e '.ok == true and .profiles == 13 and .credential == "absent" and .live_by_default == false' <<<"$health" >/dev/null

profiles="$("$JUDGE" list)"
jq -e '.profiles | length == 13' <<<"$profiles" >/dev/null
jq -e '[.profiles[].id] | index("skill-suggestion") != null and index("task-state-fallback") != null and index("self-improvement-diagnosis") != null' <<<"$profiles" >/dev/null

"$JUDGE" show claim-evidence | jq -e '.authority == "advisory" and (.questions | keys | length == 2)' >/dev/null
"$JUDGE" show self-improvement-diagnosis | jq -e '.authority == "diagnostic" and .calibration_status == "pending_corpus" and (.questions | keys == ["pattern"])' >/dev/null

"$ROOT/scripts/harness-trace-retrospect" --adapter pi --trace-file "$ROOT/tests/fixtures/harness-traces/pi/session.jsonl" --ledger "$ROOT/tests/fixtures/harness-traces/pi/events.jsonl" --run pi-run --json >"$TMP/observation.json"
prepared="$($JUDGE prepare-self-improvement --observation-file "$TMP/observation.json")"
jq -e '(.state | keys | sort == ["episode", "signals"]) and (.questions | keys == ["pattern"]) and (.state.episode | contains("completeness=complete"))' <<<"$prepared" >/dev/null
for forbidden in 'action=recommendation' 'category=validation_failure' '/private' 'session.jsonl' 'private prompt response'; do
  if grep -F "$forbidden" <<<"$prepared" >/dev/null; then
    echo "jev-judge-smoke: prepared diagnosis leaked preselected or private state" >&2
    exit 1
  fi
done
if "$JUDGE" evaluate self-improvement-diagnosis --state-file "$TMP/observation.json" --live --no-receipt >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: generic evaluation bypassed diagnosis eligibility" >&2
  exit 1
fi
grep -q 'requires the dedicated diagnosis command' "$TMP/err"
if "$JUDGE" diagnose-self-improvement --observation-file "$TMP/observation.json" >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: diagnosis succeeded without --live" >&2
  exit 1
fi
grep -q 'requires explicit --live' "$TMP/err"

canary="$($JUDGE canary-self-improvement --trace-file "$ROOT/tests/fixtures/harness-traces/pi/session-bound.jsonl" --ledger "$ROOT/tests/fixtures/harness-traces/pi/events.jsonl" --run pi-run)"
jq -e '.canary == "self_improvement_diagnosis" and .mode == "prepared" and .binding == "native_correlated" and .completeness == "complete" and .profile == "self-improvement-diagnosis" and .authority == "diagnostic" and .status == "prepared" and .diagnosis == null and .reason == null and .provider == null and .model == null' <<<"$canary" >/dev/null
for forbidden in 'private' '/private' 'pi-run' 'pi-private-session' '926a4c832da5' 'state_fingerprint' 'question_fingerprint'; do
  if grep -F "$forbidden" <<<"$canary" >/dev/null; then
    echo "jev-judge-smoke: canary leaked private or fingerprint state" >&2
    exit 1
  fi
done
live_canary="$(env -u TYPESAFE_API_KEY "$JUDGE" canary-self-improvement --trace-file "$ROOT/tests/fixtures/harness-traces/pi/session-bound.jsonl" --ledger "$ROOT/tests/fixtures/harness-traces/pi/events.jsonl" --run pi-run --live)"
jq -e '.mode == "live" and .status == "abstain" and .reason == "missing_api_key" and .diagnosis == null and .provider == "typesafe-system-one" and .model == "jev-1.13.0"' <<<"$live_canary" >/dev/null
if "$JUDGE" canary-self-improvement --trace-file "$ROOT/tests/fixtures/harness-traces/pi/session.jsonl" --ledger "$ROOT/tests/fixtures/harness-traces/pi/events.jsonl" --run pi-run >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: canary accepted an unbound observation" >&2
  exit 1
fi
test "$(cat "$TMP/err")" = 'jev-judge: canary_unavailable'
if "$JUDGE" canary-self-improvement --trace-file "$TMP/private-missing-session.jsonl" --ledger "$ROOT/tests/fixtures/harness-traces/pi/events.jsonl" --run pi-run >"$TMP/out" 2>"$TMP/err"; then
  echo "jev-judge-smoke: canary accepted a missing private trace" >&2
  exit 1
fi
test "$(cat "$TMP/err")" = 'jev-judge: canary_unavailable'

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
