#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CLEANUP="$ROOT_DIR/scripts/plan-cleanup"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  printf 'plan-cleanup smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$CLEANUP" ] || fail "missing executable plan-cleanup"

# Every case prepares its own PLAN.md before invoking the CLI, so cases are
# independent; each lane runs in its own directory tree and in parallel.
CASE_DIR=""

write_plan() {
  cat >"$CASE_DIR/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY

## Goal

Finish a bounded implementation.
PLAN
}

write_status_plan() {
  {
    printf '%s\n\n' 'PLAN heading placeholder'
    printf '%s\n' '## Meta'
    printf -- '- Status: %s\n' "$1"
    printf -- '- Last revised: %s\n' "$2"
  } >"$CASE_DIR/PLAN.md"
}

status_json() {
  (cd "$CASE_DIR" && "$CLEANUP" --status "$@")
}

case_archive_valid() {
  write_plan
  mkdir -p "$CASE_DIR/docs/plan"
  hash="$(shasum -a 256 "$CASE_DIR/PLAN.md" | awk '{print $1}')"
  cat >"$CASE_DIR/docs/plan/implemented.md" <<EOF
# Implemented: bounded implementation

- Source plan: \`PLAN.md\` — bounded implementation
- Source plan SHA-256: \`$hash\`
- Status: IMPLEMENTED
EOF

  output="$(cd "$CASE_DIR" && "$CLEANUP" --archive docs/plan/implemented.md)"
  printf '%s\n' "$output" | jq -e '.removed == "PLAN.md" and .archive == "docs/plan/implemented.md"' >/dev/null ||
    fail "valid cleanup did not report its archive"
  [ ! -e "$CASE_DIR/PLAN.md" ] || fail "valid cleanup did not remove root PLAN.md"
}

case_archive_rejections() {
  write_plan
  mkdir -p "$CASE_DIR/docs/plan"
  cat >"$CASE_DIR/docs/plan/invalid.md" <<'EOF'
# Implemented: invalid archive

- Source plan: `PLAN.md`
- Status: IMPLEMENTED
EOF
  if (cd "$CASE_DIR" && "$CLEANUP" --archive docs/plan/invalid.md >/dev/null 2>&1); then
    fail "cleanup accepted an archive without matching plan hash"
  fi
  [ -f "$CASE_DIR/PLAN.md" ] || fail "invalid cleanup removed PLAN.md"

  if (cd "$CASE_DIR" && "$CLEANUP" --archive ../outside.md >/dev/null 2>&1); then
    fail "cleanup accepted an archive outside docs/plan"
  fi
  [ -f "$CASE_DIR/PLAN.md" ] || fail "outside archive cleanup removed PLAN.md"
}

case_discard_valid() {
  write_plan
  discard_output="$(cd "$CASE_DIR" && "$CLEANUP" --discard unrelated-to-request)"
  printf '%s\n' "$discard_output" | jq -e '.removed == "PLAN.md" and .mode == "discard" and .reason == "unrelated-to-request"' >/dev/null ||
    fail "discard did not report mode/reason"
  [ ! -e "$CASE_DIR/PLAN.md" ] || fail "discard did not remove root PLAN.md"
  discard_record="$(printf '%s\n' "$discard_output" | jq -r '.record')"
  [ -f "$CASE_DIR/$discard_record" ] || fail "discard did not write record"
  grep -q 'Status: DISCARDED' "$CASE_DIR/$discard_record" || fail "discard record missing DISCARDED status"
}

case_discard_bad_reason() {
  write_plan
  if (cd "$CASE_DIR" && "$CLEANUP" --discard 'Bad Reason' >/dev/null 2>&1); then
    fail "discard accepted a non-slug reason"
  fi
  [ -f "$CASE_DIR/PLAN.md" ] || fail "invalid discard removed PLAN.md"
}

case_status_missing_and_fresh() {
  rm -f "$CASE_DIR/PLAN.md"
  missing_out="$(status_json)" || fail "--status failed on a missing plan"
  printf '%s\n' "$missing_out" | jq -e '.status == "missing" and .stale == false' >/dev/null ||
    fail "--status did not report a missing plan"

  write_status_plan READY "$(date -u +%Y-%m-%d)"
  fresh_out="$(status_json)" || fail "--status failed on a fresh READY plan"
  printf '%s\n' "$fresh_out" | jq -e '.status == "ready" and .stale == false and .ageDays == 0' >/dev/null ||
    fail "--status did not report a fresh READY plan"
  [ -f "$CASE_DIR/PLAN.md" ] || fail "--status removed PLAN.md"
}

case_status_stale() {
  write_status_plan READY 2020-01-01
  if stale_out="$(status_json)"; then
    fail "--status accepted a stale READY plan"
  fi
  printf '%s\n' "$stale_out" | jq -e '.status == "ready" and .stale == true' >/dev/null ||
    fail "--status did not report a stale READY plan"
  [ -f "$CASE_DIR/PLAN.md" ] || fail "stale --status removed PLAN.md"

  status_json --max-age-days 100000 >/dev/null ||
    fail "--max-age-days did not relax the staleness threshold"
}

case_status_invalid() {
  write_status_plan DONE 2020-01-01
  if invalid_out="$(status_json)"; then
    fail "--status accepted an invalid plan status"
  fi
  printf '%s\n' "$invalid_out" | jq -e '.status == "invalid"' >/dev/null ||
    fail "--status did not report an invalid plan status"
  [ -f "$CASE_DIR/PLAN.md" ] || fail "invalid --status removed PLAN.md"
}

case_status_commented_and_undated() {
  write_status_plan READY "2026-04-01 (Round 4 — trailing comment)"
  if commented_out="$(status_json)"; then
    fail "--status ignored a stale date carrying a trailing comment"
  fi
  printf '%s\n' "$commented_out" | jq -e '.ageDays != null and .stale == true' >/dev/null ||
    fail "--status did not parse a date with a trailing comment"

  write_status_plan READY ""
  undated_out="$(status_json)" || fail "--status failed on a plan without a usable date"
  printf '%s\n' "$undated_out" | jq -e '.ageDays == null and .stale == false' >/dev/null ||
    fail "--status guessed an age for an unparseable date"
}

case_status_bad_flags_and_impossible_date() {
  write_status_plan READY ""
  if status_json --max-age-days notanumber >/dev/null 2>&1; then
    fail "--status accepted a non-numeric --max-age-days"
  fi

  write_status_plan READY 2026-13-45
  impossible_out="$(status_json)" || fail "--status failed on an impossible date"
  printf '%s\n' "$impossible_out" | jq -e '.ageDays == null and .stale == false' >/dev/null ||
    fail "--status rolled an impossible date into a real one"
}

case_status_future() {
  write_status_plan READY 2099-01-01
  if future_out="$(status_json)"; then
    fail "--status accepted a future-dated plan"
  fi
  printf '%s\n' "$future_out" | jq -e '.futureDated == true' >/dev/null ||
    fail "--status did not flag a future-dated plan"
}

case_status_decorated() {
  for decorated in 'READY (round 3)' 'Ready for review' 'DRAFT | CHALLENGED | READY'; do
    write_status_plan "$decorated" "$(date -u +%Y-%m-%d)"
    if decorated_out="$(status_json)"; then
      fail "--status accepted a status the router cannot read: $decorated"
    fi
    printf '%s\n' "$decorated_out" | jq -e '.status == "invalid" and .gateVisible == false' >/dev/null ||
      fail "--status did not mark a router-invisible status invalid: $decorated"
  done
}

case_status_headerless() {
  {
    printf '%s\n\n' 'PLAN heading placeholder'
    printf '%s\n' '## Meta'
    printf -- '- Last revised: %s\n' "$(date -u +%Y-%m-%d)"
  } >"$CASE_DIR/PLAN.md"
  if headerless_out="$(status_json)"; then
    fail "--status accepted a plan with no Status line"
  fi
  printf '%s\n' "$headerless_out" | jq -e '.status == "missing-status" and .gateVisible == false' >/dev/null ||
    fail "--status did not flag a headerless plan as router-invisible"
}

case_extra_arguments() {
  write_plan
  (cd "$CASE_DIR" && "$CLEANUP" --archive docs/plan/x.md extra >/dev/null 2>&1) &&
    fail "--archive accepted an extra argument"
  (cd "$CASE_DIR" && "$CLEANUP" --discard reason extra >/dev/null 2>&1) &&
    fail "--discard accepted an extra argument"
  [ -f "$CASE_DIR/PLAN.md" ] || fail "extra-argument rejection removed PLAN.md"
}

LANES=(
  case_archive_valid
  case_archive_rejections
  case_discard_valid
  case_discard_bad_reason
  case_status_missing_and_fresh
  case_status_stale
  case_status_invalid
  case_status_commented_and_undated
  case_status_bad_flags_and_impossible_date
  case_status_future
  case_status_decorated
  case_status_headerless
  case_extra_arguments
)

pids=()
labels=()
for lane in "${LANES[@]}"; do
  lane_dir="$(mktemp -d "$TMP_ROOT/lane.XXXXXX")"
  (
    CASE_DIR="$lane_dir"
    "$lane"
  ) &
  pids+=("$!")
  labels+=("$lane")
done

overall=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    printf 'plan-cleanup smoke: lane %s failed\n' "${labels[$i]}" >&2
    overall=1
  fi
done
[ "$overall" -eq 0 ] || exit 1

printf 'plan-cleanup smoke test: ok\n'
