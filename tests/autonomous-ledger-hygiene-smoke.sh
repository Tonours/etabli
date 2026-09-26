#!/usr/bin/env bash
# C6: autonomous-completed profile fails incomplete ledgers and passes complete ones.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
. "$ROOT_DIR/scripts/lib/hash.sh"
EVENT="$ROOT_DIR/scripts/workflow-event"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DIR="$TMP/.workflow"
LOCKF_BIN=""
FLOCK_BIN=""
[ ! -x /usr/bin/lockf ] || LOCKF_BIN=/usr/bin/lockf
[ -n "$LOCKF_BIN" ] || [ ! -x /usr/sbin/lockf ] || LOCKF_BIN=/usr/sbin/lockf
[ ! -x /usr/bin/flock ] || FLOCK_BIN=/usr/bin/flock
[ -n "$FLOCK_BIN" ] || [ ! -x /bin/flock ] || FLOCK_BIN=/bin/flock

fail() {
  printf 'autonomous ledger hygiene smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$EVENT" ] || fail "workflow-event missing"

expect_status() {
  local expected="$1"
  shift
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  [ "$status" -eq "$expected" ] || fail "expected status $expected, got $status: $output"
  printf '%s' "$output"
}

append_autonomous_evidence() {
  local slug="$1"
  "$EVENT" --dir "$DIR" append "$slug" plan_created '{"path":"PLAN.md","status":"READY"}'
  "$EVENT" --dir "$DIR" append "$slug" adversary_completed '{"mode":"plan","verdict":"READY","accepted_findings":[],"rejected_findings":[]}'
  "$EVENT" --dir "$DIR" append "$slug" file_changed '{"path":"scripts/x","change":"added"}'
  "$EVENT" --dir "$DIR" append "$slug" validation_run '{"command":"true","exit":0}'
  "$EVENT" --dir "$DIR" append "$slug" adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
  "$EVENT" --dir "$DIR" append "$slug" simplification_completed '{"status":"ok","evidence":"none"}'
  "$EVENT" --dir "$DIR" append "$slug" review_completed '{"status":"GO","evidence":"fresh-context GO"}'
}

append_autonomous_closeout() {
  local slug="$1"
  "$EVENT" --dir "$DIR" append "$slug" archive_written '{"path":"docs/plan/example.md"}'
  "$EVENT" --dir "$DIR" append "$slug" plan_removed '{"path":"PLAN.md"}'
}

assert_transients_clean() {
  if find "$DIR" -type d -name '.completion-candidate.*' -print -quit | grep -q .; then
    fail "completion candidate directory leaked"
  fi
  if find "$DIR" -type f -name 'events.lock.owner.json' -print -quit | grep -q .; then
    fail "lock owner metadata leaked"
  fi
}

# Structural and schema-v1 routes retain their historical completion behavior.
"$EVENT" --dir "$DIR" append structural route_decided '{"route":"plan-loop","reason":"structural compatibility"}'
"$EVENT" --dir "$DIR" append structural completed '{"summary":"structural complete"}'
"$EVENT" --dir "$DIR" validate structural >/dev/null
mkdir -p "$DIR/legacy-route"
legacy_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "{\"schema_version\":1,\"ts\":\"$legacy_ts\",\"event\":\"route_decided\",\"run\":\"legacy-route\",\"detail\":{\"route\":\"plan-implement\",\"reason\":\"legacy compatibility\"}}" > "$DIR/legacy-route/events.jsonl"
"$EVENT" --dir "$DIR" append legacy-route completed '{"summary":"legacy structural complete"}'
"$EVENT" --dir "$DIR" validate legacy-route >/dev/null

# An internal call under an unrelated native lock cannot write while another process
# holds the canonical lock, even when the wrong parent inherits an open canonical FD.
slug="wrong-native-lock"
"$EVENT" --dir "$DIR" append "$slug" route_decided '{"route":"plan-loop","reason":"native canonical descriptor attack"}'
ledger="$DIR/$slug/events.jsonl"
canonical_lock="$DIR/$slug/events.lock"
lock_ready="$TMP/native-lock-ready"
wrong_lock="$TMP/wrong-events.lock"
before_sha="$(hash256 "$ledger" | awk '{print $1}')"
if [ -n "$LOCKF_BIN" ]; then
  "$LOCKF_BIN" -k "$canonical_lock" sh -c 'touch "$1"; sleep 2' sh "$lock_ready" &
  holder_pid=$!
  backend="lockf"
else
  [ -n "$FLOCK_BIN" ] || fail "no native lock backend for attack fixture"
  "$FLOCK_BIN" -x "$canonical_lock" sh -c 'touch "$1"; sleep 2' sh "$lock_ready" &
  holder_pid=$!
  backend="flock"
fi
attempt=0
while [ ! -f "$lock_ready" ] && [ "$attempt" -lt 100 ]; do
  sleep 0.02
  attempt=$((attempt + 1))
done
[ -f "$lock_ready" ] || fail "canonical lock holder did not start"
token="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
forged_capability="$DIR/$slug/.lock-capability.$token.json"
jq -nc \
  --arg token "$token" \
  --arg backend "$backend" \
  --arg lock_file "$canonical_lock" \
  --argjson request_pid "$$" \
  '{schema_version:1,token:$token,backend:$backend,lock_file:$lock_file,request_pid:$request_pid}' > "$forged_capability"
wrong_native_lock_attack() (
  cd "$DIR/$slug"
  exec 9<events.lock
  if [ "$backend" = "lockf" ]; then
    "$LOCKF_BIN" -k "$wrong_lock" "$EVENT" --dir "$DIR" _append-locked "$slug" completed '{"summary":"wrong lock bypass"}' "$token" lockf
  else
    "$FLOCK_BIN" -x "$wrong_lock" "$EVENT" --dir "$DIR" _append-locked "$slug" completed '{"summary":"wrong lock bypass"}' "$token" flock
  fi
)
out="$(expect_status 1 wrong_native_lock_attack)"
printf '%s\n' "$out" | grep -Fq 'parent did not target the canonical lock invocation' || fail "wrong-lock attack did not fail at canonical invocation boundary"
wait "$holder_pid"
[ "$(hash256 "$ledger" | awk '{print $1}')" = "$before_sha" ] || fail "wrong-lock attack changed canonical ledger"
[ "$(jq -s '[.[] | select(.event == "completed")] | length' "$ledger")" -eq 0 ] || fail "wrong-lock attack appended a terminal"
[ -f "$forged_capability" ] || fail "writer mutated the caller-owned forged file"
[ ! -e "$forged_capability.used" ] || fail "writer consumed the forged capability"
assert_transients_clean

# Caller-controlled PATH helpers cannot forge the native parent or lock proof.
fake_bin="$TMP/fake-bin"
mkdir -p "$fake_bin"
printf '%s\n' '#!/bin/sh' 'case "$*" in *command=*) printf "%s\n" "lockf -t 5 /dev/fd/9 fake" ;; *) printf "%s\n" lockf ;; esac' > "$fake_bin/ps"
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$FAKE_PARENT_CWD"' > "$fake_bin/readlink"
printf '%s\n' '#!/bin/sh' 'printf "n%s\n" "$FAKE_PARENT_CWD"' > "$fake_bin/lsof"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$fake_bin/lockf"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$fake_bin/flock"
chmod +x "$fake_bin/ps" "$fake_bin/readlink" "$fake_bin/lsof" "$fake_bin/lockf" "$fake_bin/flock"
before_sha="$(hash256 "$ledger" | awk '{print $1}')"
out="$(expect_status 1 env PATH="$fake_bin:$PATH" FAKE_PARENT_CWD="$DIR/$slug" "$EVENT" --dir "$DIR" _append-locked "$slug" completed '{"summary":"forged PATH bypass"}' "$token" "$backend")"
printf '%s\n' "$out" | grep -Eq 'declared OS lock parent|trusted native lock executable' || fail "forged PATH attack did not fail at trusted process boundary"
[ "$(hash256 "$ledger" | awk '{print $1}')" = "$before_sha" ] || fail "forged PATH attack changed canonical ledger"
[ "$(jq -s '[.[] | select(.event == "completed")] | length' "$ledger")" -eq 0 ] || fail "forged PATH attack appended a terminal"
assert_transients_clean

# Locking a descriptor for a displaced inode cannot borrow a separate lock on
# a replacement events.lock pathname.
slug="replaced-native-lock"
"$EVENT" --dir "$DIR" append "$slug" route_decided '{"route":"plan-loop","reason":"native pathname replacement attack"}'
ledger="$DIR/$slug/events.jsonl"
before_sha="$(hash256 "$ledger" | awk '{print $1}')"
swap_ready="$TMP/swap-lock-ready"
pathname_swap_attack() (
  cd "$DIR/$slug"
  exec 9>>events.lock
  mv events.lock displaced-events.lock
  : > events.lock
  if [ "$backend" = "lockf" ]; then
    "$LOCKF_BIN" -k events.lock sh -c 'touch "$1"; sleep 2' sh "$swap_ready" &
  else
    "$FLOCK_BIN" -x events.lock sh -c 'touch "$1"; sleep 2' sh "$swap_ready" &
  fi
  swap_holder_pid=$!
  attempt=0
  while [ ! -f "$swap_ready" ] && [ "$attempt" -lt 100 ]; do
    sleep 0.02
    attempt=$((attempt + 1))
  done
  [ -f "$swap_ready" ] || exit 3
  if [ "$backend" = "lockf" ]; then
    "$LOCKF_BIN" -t 5 /dev/fd/9 "$EVENT" --dir "$DIR" _append-locked "$slug" completed '{"summary":"pathname swap bypass"}' "$token" lockf
  else
    "$FLOCK_BIN" -w 5 9 "$EVENT" --dir "$DIR" _append-locked "$slug" completed '{"summary":"pathname swap bypass"}' "$token" flock
  fi
  attack_status=$?
  wait "$swap_holder_pid"
  exit "$attack_status"
)
out="$(expect_status 1 pathname_swap_attack)"
printf '%s\n' "$out" | grep -Fq 'parent lock descriptor is not canonical' || fail "pathname replacement attack did not fail at descriptor identity boundary"
[ "$(hash256 "$ledger" | awk '{print $1}')" = "$before_sha" ] || fail "pathname replacement attack changed canonical ledger"
[ "$(jq -s '[.[] | select(.event == "completed")] | length' "$ledger")" -eq 0 ] || fail "pathname replacement attack appended a terminal"
assert_transients_clean

# A later route cannot downgrade a schema-v2 plan-implement run. Refusal is byte-exact.
slug="missing-plan-removed"
"$EVENT" --dir "$DIR" append "$slug" route_decided '{"route":"plan-implement","reason":"monotone autonomous route"}'
"$EVENT" --dir "$DIR" append "$slug" route_decided '{"route":"answer","reason":"must not disable autonomous completion guard"}'
append_autonomous_evidence "$slug"
"$EVENT" --dir "$DIR" append "$slug" archive_written '{"path":"docs/plan/example.md"}'
"$EVENT" --dir "$DIR" activate "$slug" >/dev/null
ledger="$DIR/$slug/events.jsonl"
pointer="$DIR/active-run.json"
before_sha="$(hash256 "$ledger" | awk '{print $1}')"
before_bytes="$(wc -c < "$ledger" | tr -d ' ')"
before_lines="$(wc -l < "$ledger" | tr -d ' ')"
pointer_sha="$(hash256 "$pointer" | awk '{print $1}')"
out="$(expect_status 1 "$EVENT" --dir "$DIR" append "$slug" completed '{"summary":"must be rejected without plan_removed"}')"
printf '%s\n' "$out" | grep -Fq 'before profile prerequisites pass' || fail "missing autonomous refusal message"
[ "$(hash256 "$ledger" | awk '{print $1}')" = "$before_sha" ] || fail "refusal changed ledger hash"
[ "$(wc -c < "$ledger" | tr -d ' ')" = "$before_bytes" ] || fail "refusal changed ledger bytes"
[ "$(wc -l < "$ledger" | tr -d ' ')" = "$before_lines" ] || fail "refusal changed ledger line count"
[ "$(hash256 "$pointer" | awk '{print $1}')" = "$pointer_sha" ] || fail "refusal changed active pointer"
assert_transients_clean

# Appending the missing plan_removed recovers the same run; the validated terminal line is the only byte suffix.
"$EVENT" --dir "$DIR" append "$slug" plan_removed '{"path":"PLAN.md"}'
cp "$ledger" "$TMP/before-success.jsonl"
"$EVENT" --dir "$DIR" append "$slug" completed '{"summary":"autonomous hygiene complete"}'
terminal_line="$(tail -n 1 "$ledger")"
cp "$TMP/before-success.jsonl" "$TMP/expected-success.jsonl"
printf '%s\n' "$terminal_line" >> "$TMP/expected-success.jsonl"
cmp -s "$TMP/expected-success.jsonl" "$ledger" || fail "successful completion changed bytes beyond the validated terminal line"
[ ! -e "$pointer" ] || fail "successful completion did not clear active pointer"
"$EVENT" --dir "$DIR" validate "$slug" --profile autonomous-completed >/dev/null
assert_transients_clean

# Two concurrent completions serialize to exactly one terminal append.
slug="concurrent-complete"
"$EVENT" --dir "$DIR" append "$slug" route_decided '{"route":"plan-implement","reason":"concurrent completion"}'
append_autonomous_evidence "$slug"
append_autonomous_closeout "$slug"
set +e
"$EVENT" --dir "$DIR" append "$slug" completed '{"summary":"concurrent complete"}' >"$TMP/complete-a.out" 2>&1 &
pid_a=$!
"$EVENT" --dir "$DIR" append "$slug" completed '{"summary":"concurrent complete"}' >"$TMP/complete-b.out" 2>&1 &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e
[ $((status_a + status_b)) -eq 1 ] || fail "concurrent completions must yield one success and one failure: $status_a/$status_b"
[ "$(jq -s '[.[] | select(.event == "completed")] | length' "$DIR/$slug/events.jsonl")" -eq 1 ] || fail "concurrent completion wrote more than one terminal"
"$EVENT" --dir "$DIR" validate "$slug" --profile autonomous-completed >/dev/null
assert_transients_clean

# Closeout/completed races can stop non-terminal, but never as terminal-incomplete; retry converges.
slug="closeout-race"
"$EVENT" --dir "$DIR" append "$slug" route_decided '{"route":"plan-implement","reason":"closeout completion race"}'
append_autonomous_evidence "$slug"
"$EVENT" --dir "$DIR" append "$slug" archive_written '{"path":"docs/plan/example.md"}'
set +e
"$EVENT" --dir "$DIR" append "$slug" plan_removed '{"path":"PLAN.md"}' >"$TMP/metric.out" 2>&1 &
metric_pid=$!
"$EVENT" --dir "$DIR" append "$slug" completed '{"summary":"closeout race complete"}' >"$TMP/race-complete.out" 2>&1 &
complete_pid=$!
wait "$metric_pid"; metric_status=$?
wait "$complete_pid"; complete_status=$?
set -e
[ "$metric_status" -eq 0 ] || fail "plan_removed lost its race append"
terminal_count="$(jq -s '[.[] | select(.event == "completed")] | length' "$DIR/$slug/events.jsonl")"
if [ "$terminal_count" -eq 1 ]; then
  "$EVENT" --dir "$DIR" validate "$slug" --profile autonomous-completed >/dev/null
else
  [ "$terminal_count" -eq 0 ] || fail "closeout race wrote multiple terminals"
  [ "$complete_status" -ne 0 ] || fail "completion reported success without a terminal"
  "$EVENT" --dir "$DIR" validate "$slug" >/dev/null
  "$EVENT" --dir "$DIR" append "$slug" completed '{"summary":"closeout race complete"}'
  "$EVENT" --dir "$DIR" validate "$slug" --profile autonomous-completed >/dev/null
fi
assert_transients_clean

# Pin: implementation-loop / ship mention autonomous ledger
grep -Fq 'events.jsonl' "$ROOT_DIR/workflow/skills/implementation-loop.md" ||
  fail "implementation-loop must mention event ledger"
grep -Fq 'autonomous' "$ROOT_DIR/workflow/skills/ship.md" ||
  fail "ship skill must mention autonomous rules"

printf 'autonomous ledger hygiene smoke test: ok\n'
