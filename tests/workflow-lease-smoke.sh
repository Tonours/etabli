#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LEASE="$ROOT_DIR/scripts/workflow-lease"

fail() { printf 'workflow-lease-smoke: %s\n' "$1" >&2; exit 1; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/workflow-lease.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
DIR="$TMP_ROOT/.workflow"
mkdir -p "$TMP_ROOT/repo" "$TMP_ROOT/wt"
W=(--dir "$DIR")
R=(--repo "$TMP_ROOT/repo" --worktree "$TMP_ROOT/wt")

lease_show() { "$LEASE" "${W[@]}" show "${R[@]}"; }
holder_token() { lease_show | jq -r .token; }
reset_leases() { rm -rf "$DIR"; mkdir -p "$DIR"; }

reset_leases
for i in $(seq 1 10); do
  (set +e; "$LEASE" "${W[@]}" acquire "${R[@]}" --owner "worker$i" --ttl-secs 60 >"$TMP_ROOT/t1-$i.out" 2>"$TMP_ROOT/t1-$i.err"; echo $? >"$TMP_ROOT/t1-$i.ec") &
done
wait
winners=0
for i in $(seq 1 10); do
  if [ "$(cat "$TMP_ROOT/t1-$i.ec")" = "0" ] && jq -e '.schema_version == 2 and (.token | length == 32)' "$TMP_ROOT/t1-$i.out" >/dev/null 2>&1; then
    winners=$((winners + 1))
  fi
done
[ "$winners" = "1" ] || fail "T1: expected exactly 1 acquire winner, got $winners"
n_records=$(find "$DIR/leases" -maxdepth 1 -name '*.json' ! -name '*.history.jsonl' | wc -l | tr -d ' ')
[ "$n_records" = "1" ] || fail "T1: expected 1 lease record, got $n_records"

reset_leases
"$LEASE" "${W[@]}" acquire "${R[@]}" --owner crashed --ttl-secs 1 >/dev/null
sleep 1.2
TOK2=$(holder_token)
if "$LEASE" "${W[@]}" renew "${R[@]}" --token "$TOK2" >/dev/null 2>&1; then
  fail "T2: renew on expired lease must fail"
fi

"$LEASE" "${W[@]}" recover "${R[@]}" --owner rescuer "smoke-t3-crash-cleanup" | jq -e '.schema_version == 2 and .owner == "rescuer"' >/dev/null \
  || fail "T3: recover on expired lease must succeed and honor --owner"
grep -q '"event":"recover"' "$DIR"/leases/*.history.jsonl || fail "T3: recover must log history"

reset_leases
WORKFLOW_LEASE_HOSTNAME=host-a "$LEASE" "${W[@]}" acquire "${R[@]}" --owner mini --ttl-secs 60 >/dev/null
if WORKFLOW_LEASE_HOSTNAME=host-b "$LEASE" "${W[@]}" acquire "${R[@]}" --owner laptop >/dev/null 2>&1; then
  fail "T4: acquire from second host on valid lease must fail"
fi
WORKFLOW_LEASE_HOSTNAME=host-b "$LEASE" "${W[@]}" acquire "${R[@]}" --owner laptop 2>"$TMP_ROOT/t4.err" || true
grep -q 'another host' "$TMP_ROOT/t4.err" || fail "T4: refusal must name the foreign host"
if WORKFLOW_LEASE_HOSTNAME=host-b "$LEASE" "${W[@]}" recover "${R[@]}" "still-valid" >/dev/null 2>&1; then
  fail "T4: recover on valid lease must fail"
fi
TOK4=$(WORKFLOW_LEASE_HOSTNAME=host-a "$LEASE" "${W[@]}" show "${R[@]}" | jq -r .token)
WORKFLOW_LEASE_HOSTNAME=host-a "$LEASE" "${W[@]}" release "${R[@]}" --token "$TOK4" >/dev/null
WORKFLOW_LEASE_HOSTNAME=host-a "$LEASE" "${W[@]}" acquire "${R[@]}" --owner mini --ttl-secs 1 >/dev/null
sleep 1.2
WORKFLOW_LEASE_HOSTNAME=host-b "$LEASE" "${W[@]}" recover "${R[@]}" "smoke-t4-takeover" | jq -e '.hostname == "host-b"' >/dev/null \
  || fail "T4: expired takeover from second host must succeed"

reset_leases
"$LEASE" "${W[@]}" acquire "${R[@]}" --owner renewer --ttl-secs 60 >/dev/null
TOK5=$(holder_token)
E1=$(lease_show | jq -r .expires_epoch)
sleep 1
"$LEASE" "${W[@]}" renew "${R[@]}" --token "$TOK5" >/dev/null
E2=$(lease_show | jq -r .expires_epoch)
[ "$E2" -gt "$E1" ] || fail "T5: renew must extend expiry ($E2 <= $E1)"
lease_show | jq -e '.heartbeat_at != null' >/dev/null || fail "T5: renew must refresh heartbeat"

reset_leases
"$LEASE" "${W[@]}" acquire "${R[@]}" --owner victim --ttl-secs 60 >/dev/null
printf '{"garbage":true}\n' >"$DIR"/leases/*.json
if "$LEASE" "${W[@]}" acquire "${R[@]}" --owner next >/dev/null 2>"$TMP_ROOT/t6.err"; then
  fail "T6: malformed owner must fail closed"
fi
grep -q 'malformed lease owner record' "$TMP_ROOT/t6.err" || fail "T6: refusal must name malformed record"

reset_leases
OLD=$("$LEASE" "${W[@]}" acquire "${R[@]}" --owner A --ttl-secs 1 | jq -r .token)
sleep 1.2
NEW=$("$LEASE" "${W[@]}" recover "${R[@]}" "smoke-t7-a-crashed" | jq -r .token)
[ "$OLD" != "$NEW" ] || fail "T7: takeover must mint a new token"
if "$LEASE" "${W[@]}" renew "${R[@]}" --token "$OLD" >/dev/null 2>"$TMP_ROOT/t7.err"; then
  fail "T7: stale renew must fail"
fi
grep -q 'stale generation' "$TMP_ROOT/t7.err" || fail "T7: stale renew refusal must say stale generation"
if "$LEASE" "${W[@]}" release "${R[@]}" --token "$OLD" >/dev/null 2>&1; then
  fail "T7: stale release must fail"
fi
"$LEASE" "${W[@]}" release "${R[@]}" --token "$NEW" >/dev/null || fail "T7: current holder release must succeed"

reset_leases
ln -s "$TMP_ROOT/wt" "$TMP_ROOT/wt-alias"
"$LEASE" "${W[@]}" acquire --repo "$TMP_ROOT/repo" --worktree "$TMP_ROOT/wt-alias" --owner alias --ttl-secs 60 >/dev/null
"$LEASE" "${W[@]}" show --repo "$TMP_ROOT/repo" --worktree "$TMP_ROOT/wt" | jq -e '.owner == "alias"' >/dev/null \
  || fail "T8: aliased worktree must resolve to the canonical scope"

reset_leases
if "$LEASE" "${W[@]}" acquire --repo "$TMP_ROOT/does-not-exist" --worktree "$TMP_ROOT/wt" --owner ghost --ttl-secs 60 >/dev/null 2>&1; then
  fail "T9: a nonexistent repo path must fail the whole command"
fi
[ ! -e "$TMP_ROOT/does-not-exist" ] || fail "T9: canonicalization must not create paths"
[ -z "$(ls "$DIR/leases" 2>/dev/null)" ] || fail "T9: no lease record may appear for a failed scope"

reset_leases
"$LEASE" "${W[@]}" acquire "${R[@]}" --owner traceless --ttl-secs 1 >/dev/null
sleep 1.2
lease_key="$(basename "$(find "$DIR/leases" -maxdepth 1 -name '*.json' | head -1)" .json)"
mkdir -p "$DIR/leases/$lease_key.history.jsonl"
if "$LEASE" "${W[@]}" recover "${R[@]}" "smoke-t10-unwritable-history" >/dev/null 2>&1; then
  fail "T10: recover must refuse when the history journal cannot be written"
fi
"$LEASE" "${W[@]}" show "${R[@]}" | jq -e '.owner == "traceless"' >/dev/null \
  || fail "T10: the expired lease must be left untouched by the refused recover"
rmdir "$DIR/leases/$lease_key.history.jsonl"
mkdir -p "$DIR/leases/$lease_key.history.jsonl"
if "$LEASE" "${W[@]}" acquire "${R[@]}" --owner ghost --ttl-secs 60 >/dev/null 2>&1; then
  fail "T11: acquire takeover must refuse when the history journal cannot be written"
fi
"$LEASE" "${W[@]}" show "${R[@]}" | jq -e '.owner == "traceless"' >/dev/null \
  || fail "T11: the expired lease must be left untouched by the refused takeover"
rmdir "$DIR/leases/$lease_key.history.jsonl"

reset_leases
"$LEASE" "${W[@]}" acquire "${R[@]}" --owner racer --ttl-secs 60 >/dev/null
TOKR=$(holder_token)
for i in 1 2 3; do
  (set +e; "$LEASE" "${W[@]}" renew "${R[@]}" --token "$TOKR" >/dev/null 2>&1; echo $? >"$TMP_ROOT/r1a.ec") &
  (set +e; "$LEASE" "${W[@]}" recover "${R[@]}" "smoke-r1-race" >/dev/null 2>&1; echo $? >"$TMP_ROOT/r1b.ec") &
  wait
  ok_a=$([ "$(cat "$TMP_ROOT/r1a.ec")" = "0" ] && echo 1 || echo 0)
  ok_b=$([ "$(cat "$TMP_ROOT/r1b.ec")" = "0" ] && echo 1 || echo 0)
  [ $((ok_a + ok_b)) -le 1 ] || fail "R1: renew and recover both succeeded (iteration $i)"
done

for i in 1 2 3; do
  reset_leases
  TOKA=$("$LEASE" "${W[@]}" acquire "${R[@]}" --owner A --ttl-secs 60 | jq -r .token)
  (set +e; "$LEASE" "${W[@]}" release "${R[@]}" --token "$TOKA" >/dev/null 2>&1; echo $? >"$TMP_ROOT/r2a.ec") &
  (set +e; "$LEASE" "${W[@]}" acquire "${R[@]}" --owner B >/dev/null 2>&1; echo $? >"$TMP_ROOT/r2b.ec") &
  wait
  state=$(lease_show 2>/dev/null | jq -r '.owner // "none"' 2>/dev/null || echo none)
  case "$state" in
    A|B|none) ;;
    *) fail "R2: incoherent lease state after race (owner=$state)" ;;
  esac
  if [ "$state" = "A" ] && [ "$(cat "$TMP_ROOT/r2b.ec")" = "0" ]; then
    fail "R2: B acquired but A still holds (iteration $i)"
  fi
done

printf 'workflow-lease-smoke: PASS (T1-T11, R1-R2)\n'
