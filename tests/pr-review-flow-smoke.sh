#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPTS="$ROOT_DIR/claude/scopes/work/scripts"
FIXTURES="$ROOT_DIR/tests/fixtures/claude-p"
REAL_HOME="$HOME"
mkdir -p "$REAL_HOME/.cache"
TMP_DIR="$(mktemp -d "$REAL_HOME/.cache/pr-review-flow-smoke.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

export HOME="$TMP_DIR/home" TMPDIR="$TMP_DIR/tmp"
export FAKE_DIR="$TMP_DIR/fake"
export FAKE_LOG="$FAKE_DIR/calls.log"
export FAKE_FIXTURES="$FIXTURES"
export GH_CONFIG_DIR="$TMP_DIR/gh-config" GH_TOKEN=invalid-flow-token GITHUB_TOKEN=invalid-flow-token
export GH_ENTERPRISE_TOKEN=invalid-flow-token GITHUB_ENTERPRISE_TOKEN=invalid-flow-token
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export PR_REVIEW_WATCH_COUNCIL="$SCRIPTS/pr-council-review/run.sh"
export PR_COUNCIL_CLAUDE="$HOME/.local/bin/claude" PR_REVIEW_WATCH_LOG="$TMP_DIR/watch.log"
export PR_REVIEW_WATCH_CI_WAIT=0 PR_REVIEW_USAGE_LOG="$TMP_DIR/usage.log"
mkdir -p "$TMPDIR" "$HOME/.local/bin" "$HOME/.claude/skills/thermo-nuclear-code-quality-review" "$FAKE_DIR" "$GH_CONFIG_DIR"
echo "thermo stub" >"$HOME/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md"

cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
printf 'gh %s\n' "$*" >>"$FAKE_LOG"
[ -z "${FAKE_GH_SLEEP:-}" ] || sleep "$FAKE_GH_SLEEP"
filter="" prev="" write=0
for arg in "$@"; do
  [ "$prev" = --jq ] && filter="$arg"
  case "$arg" in -f|-F|--input|-X|--method) write=1 ;; esac
  prev="$arg"
done
case "$1 $2" in
  "auth status") exit 0 ;;
  "api user") out='{"login":"me"}' ;;
  "pr view") out="$(cat "$FAKE_DIR/pr.json")" ;;
  "pr checks") out='[{"bucket":"pass"}]' ;;
  "api graphql") out='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}}' ;;
  *)
    case "$*" in
      api*repos/*/pulls/*/reviews*)
        if [ "$write" = 1 ]; then
          printf 'POST %s\n' "$*" >>"$FAKE_DIR/posts.log"
          [ -z "${FAKE_GH_POST_FAIL:-}" ] || exit 1
          out='{"html_url":"https://github.invalid/o/r/pull/7#review"}'
        else
          out='[]'
        fi ;;
      *) echo "fake gh: unexpected call: $*" >&2; exit 1 ;;
    esac ;;
esac
if [ -n "$filter" ]; then printf '%s' "$out" | jq -r "$filter"; else printf '%s\n' "$out"; fi
GH

cat >"$HOME/.local/bin/claude" <<'CLAUDE'
#!/bin/bash
case "$1" in
  --version) echo "2.1.308 (Claude Code)"; exit 0 ;;
  --help) [ -n "${FAKE_CLAUDE_OLD:-}" ] && echo "usage: claude" || echo "  --permission-prompts <mode>"; exit 0 ;;
esac
prompt="" prev="" flags=()
for arg in "$@"; do
  if [ "$prev" = -p ] && [ "${arg#-}" = "$arg" ]; then prompt="$arg"; else [ "$arg" = -p ] || flags+=("$arg"); fi
  prev="$arg"
done
if [ -z "$prompt" ]; then prompt="${flags[${#flags[@]}-1]}"; unset 'flags[${#flags[@]}-1]'; fi
case "$prompt" in
  /validator*) role=VALIDATOR ;;
  /code-review*) role=QUALITY ;;
  *thermo-nuclear*) role=THERMO ;;
  "Incremental review"*) role=DELTA ;;
  /forest:verify-fixes*) role=VERIFY ;;
  *) echo "fake claude: unknown prompt" >&2; exit 1 ;;
esac
printf 'claude %s GIT_TERMINAL_PROMPT=%s %s\n' "$role" "${GIT_TERMINAL_PROMPT:-unset}" "${flags[*]}" >>"$FAKE_LOG"
stderr_var="FAKE_${role}_STDERR"
[ -z "${!stderr_var:-}" ] || echo "${!stderr_var}" >&2
envelope_var="FAKE_${role}_ENVELOPE" text_var="FAKE_${role}_TEXT" rc_var="FAKE_${role}_RC" patch_var="FAKE_${role}_PATCH"
envelope="$FAKE_FIXTURES/2.1.308-${!envelope_var:-success}.json"
text="${!text_var:-}"
out="$(jq --arg t "${text//\{\{SHA\}\}/$FAKE_HEAD}" 'if (.result | type) == "string" and $t != "" then .result = $t else . end' "$envelope" | jq "${!patch_var:-.}")"
printf '%s\n' "$out"
if [ -n "${!rc_var:-}" ]; then exit "${!rc_var}"; fi
[ "$(printf '%s' "$out" | jq -r .is_error)" = false ]
CLAUDE

cat >"$HOME/.local/bin/terminal-notifier" <<'NOTIFY'
#!/bin/bash
printf 'notify %s\n' "$*" >>"$FAKE_LOG"
NOTIFY
chmod +x "$HOME/.local/bin/"*

git init -q --bare -b main "$TMP_DIR/origin.git"
git init -q -b main "$TMP_DIR/seed"
git -C "$TMP_DIR/seed" commit -q --allow-empty -m base
git -C "$TMP_DIR/seed" checkout -q -b feature
echo one >"$TMP_DIR/seed/a.txt"
git -C "$TMP_DIR/seed" add a.txt
git -C "$TMP_DIR/seed" commit -q -m one
HEAD1="$(git -C "$TMP_DIR/seed" rev-parse HEAD)"
echo two >>"$TMP_DIR/seed/a.txt"
git -C "$TMP_DIR/seed" commit -q -am two
HEAD2="$(git -C "$TMP_DIR/seed" rev-parse HEAD)"
git -C "$TMP_DIR/seed" push -q "$TMP_DIR/origin.git" main "$HEAD1:refs/pull/7/head"
git clone -q "$TMP_DIR/origin.git" "$TMP_DIR/clone"
CLONE="$TMP_DIR/clone"

set_head() {
  export FAKE_HEAD="$1"
  git -C "$TMP_DIR/seed" push -q -f "$TMP_DIR/origin.git" "$1:refs/pull/7/head"
  printf '{"number":7,"headRefOid":"%s","baseRefName":"main","url":"https://github.invalid/o/r/pull/7","title":"t","state":"OPEN","isDraft":false,"latestReviews":%s,"reviewRequests":[{"login":"me"}],"additions":1,"deletions":0}' \
    "$1" "${2:-[]}" >"$FAKE_DIR/pr.json"
}

marker() {
  printf '<!-- claudine:v1 {"kind":"run","run":"7-1-me","sha":"{{SHA}}","findings":%s,"floor":"major","suppressed":0,"security":"%s","lenses":["done"]} -->' \
    "$1" "${2:-none}"
}

STATE="$TMP_DIR/state"
KEY="$STATE/runs/o_r_7"
RC=0

run_review() {
  mkdir -p "$STATE/runs"
  : >"$FAKE_LOG"
  : >"$FAKE_DIR/posts.log"
  RC=0
  (cd "$CLONE" && PR_REVIEW_WATCH_STATE_DIR="$STATE" /bin/bash "$SCRIPTS/pr-review-watch/review-run.sh" \
    "$1" o/r 7 "$2" "$3" https://github.invalid/o/r/pull/7 "$TMP_DIR/report-$1.md" "$KEY") \
    >"$TMP_DIR/run.out" 2>&1 || RC=$?
  echo "$RC" >"$TMP_DIR/rc"
}

reset_state() { rm -rf "$STATE"; }

failures=0
check() {
  local label="$1"
  shift
  if "$@"; then
    printf 'ok   %s\n' "$label"
  else
    printf 'FAIL %s\n' "$label"
    sed 's/^/     | /' "$TMP_DIR/run.out" | tail -20
    failures=$((failures + 1))
  fi
}
approvals() { grep -c 'event=APPROVE' "$FAKE_DIR/posts.log" || true; }
called() { grep -q "^$1" "$FAKE_LOG"; }
not_called() { ! called "$1"; }
rc_is() { [ "$RC" = "$1" ]; }
no_file() { [ ! -e "$1" ]; }

case_clean_council_approves() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "clean council: fakes answered" called "claude VALIDATOR"
  check "clean council: exit 0" rc_is 0
  check "clean council: one approval" [ "$(approvals)" = 1 ]
  check "clean council: recorded clean" [ "$(cat "$KEY.council-clean" 2>/dev/null)" = "$HEAD1" ]
}

case_council_findings_wait() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  check "council with findings: fakes answered" called "claude VALIDATOR"
  check "council with findings: exit 0" rc_is 0
  check "council with findings: no approval" [ "$(approvals)" = 0 ]
  check "council with findings: done" [ "$(cat "$KEY.council-done" 2>/dev/null)" = "$HEAD1" ]
  check "council with findings: not clean" no_file "$KEY.council-clean"
}

case_phase_a_denial_vetoes() {
  reset_state
  set_head "$HEAD1"
  FAKE_QUALITY_ENVELOPE=denied FAKE_VALIDATOR_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "phase A denial: fakes answered" called "claude QUALITY"
  check "phase A denial: validator not run" not_called "claude VALIDATOR"
  check "phase A denial: veto exit" rc_is 3
  check "phase A denial: no council-done" no_file "$KEY.council-done"
  check "phase A denial: no approval" [ "$(approvals)" = 0 ]
}

case_verify_after_findings_approves() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  FAKE_DELTA_TEXT=$'no findings, nothing posted\nDELTA_FINDINGS 0\nDELTA_CONFIDENT value=true' \
    FAKE_VERIFY_TEXT=$'all fixed\nVERIFY_VERDICT reviewed=2 reopened=0 regressions=0 complete=true confident=true\nCONFIDENCE fixed' \
    run_review verify "$HEAD2" "$HEAD1"
  check "verify: fakes answered" called "claude VERIFY"
  check "verify: exit 0" rc_is 0
  check "verify: one approval" [ "$(approvals)" = 1 ]
}

incomplete_council() {
  local label="$1"
  shift
  reset_state
  set_head "$HEAD1"
  (export "$@"; run_review council "$HEAD1" -)
  RC="$(cat "$TMP_DIR/rc")"
  check "$label: fakes answered" called "claude VALIDATOR"
  check "$label: review-incomplete exit" rc_is 4
  check "$label: no council-done" no_file "$KEY.council-done"
  check "$label: no approval" [ "$(approvals)" = 0 ]
}

case_incomplete_reviews() {
  incomplete_council "marker missing" FAKE_VALIDATOR_TEXT="Review posted, run marker lost."
  incomplete_council "is_error" FAKE_VALIDATOR_TEXT="$(marker 0)" FAKE_VALIDATOR_PATCH='.is_error = true' FAKE_VALIDATOR_RC=0
  incomplete_council "error_max_turns" FAKE_VALIDATOR_ENVELOPE=error-max-turns
  incomplete_council "marker only in phase A" FAKE_QUALITY_TEXT="quoted: $(marker 0)" FAKE_VALIDATOR_TEXT="Review posted."
}

case_ticketed_then_clean_delta_waits() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Nothing posted. $(marker 0 ticketed)" run_review council "$HEAD1" -
  check "ticketed: no approval at head 1" [ "$(approvals)" = 0 ]
  check "ticketed: not recorded clean" no_file "$KEY.council-clean"
  set_head "$HEAD2"
  FAKE_DELTA_TEXT=$'no findings, nothing posted\nDELTA_FINDINGS 0\nDELTA_CONFIDENT value=true' \
    FAKE_VERIFY_TEXT=$'nothing to verify\nVERIFY_VERDICT reviewed=0 reopened=0 regressions=0 complete=true confident=true\nCONFIDENCE ok' \
    run_review verify "$HEAD2" "$HEAD1"
  check "ticketed then clean delta: fakes answered" called "claude DELTA"
  check "ticketed then clean delta: no approval" [ "$(approvals)" = 0 ]
}

watch_mode() {
  (cd "$CLONE" && PR_REVIEW_WATCH_STATE_DIR="$STATE" PR_REVIEW_WATCH_SETTLE=0 /bin/bash -c \
    ". '$SCRIPTS/pr-review-watch/watch.sh'; launch() { echo \"\$5\"; }; consider me o/r 7 '$HEAD2' url true" 2>&1 | tail -1)
}

case_watch_mode() {
  reset_state
  mkdir -p "$STATE/runs"
  : >"$FAKE_LOG"
  check "watch: a review of mine without a council marker gets a full council" [ "$(watch_mode)" = council ]
  check "watch: fakes answered" called "gh pr view"
  echo "$HEAD1" >"$KEY.council-done"
  check "watch: a council marker selects verify" [ "$(watch_mode)" = verify ]
}

watch_fn() {
  (cd "$CLONE" && PR_REVIEW_WATCH_STATE_DIR="$STATE" PR_REVIEW_WATCH_SETTLE=0 /bin/bash -c \
    ". '$SCRIPTS/pr-review-watch/watch.sh'; launch() { echo \"launch \$5\"; }; $1" 2>&1)
}

attempt_after() {
  printf '%s\tcouncil\t%s\t%s\n' "${4:-$HEAD1}" "$1" "$2" >"$KEY.status"
  touch -t "$3" "$KEY.status"
  watch_fn "next_attempt '$KEY' '$HEAD1'"
}

case_next_attempt() {
  reset_state
  mkdir -p "$STATE/runs"
  local old=202001010000 now
  now="$(date +%Y%m%d%H%M)"
  check "attempt: success is done" [ "$(attempt_after 0 1 "$old")" = done ]
  check "attempt: a veto is not retried" [ "$(attempt_after 3 1 "$old")" = stopped ]
  check "attempt: an incomplete review is not retried" [ "$(attempt_after 4 1 "$old")" = stopped ]
  check "attempt: a failure retries after the backoff" [ "$(attempt_after 1 1 "$old")" = 2 ]
  check "attempt: a timeout retries after the backoff" [ "$(attempt_after 124 1 "$old")" = 2 ]
  check "attempt: a TERM retries after the backoff" [ "$(attempt_after 143 2 "$old")" = 3 ]
  check "attempt: a fresh failure waits for the backoff" [ "$(attempt_after 1 1 "$now")" = wait ]
  check "attempt: the cap exhausts" [ "$(attempt_after 1 3 "$old")" = exhausted ]
  check "attempt: a new sha starts over" [ "$(attempt_after 3 3 "$old" "$HEAD2")" = 1 ]
  check "attempt: a fresh run waits" [ "$(attempt_after running 1 "$now")" = wait ]
  attempt_after 4 1 "$old" >/dev/null
  set_head "$HEAD1"
  : >"$FAKE_LOG"
  check "attempt: a stopped sha is logged once" [ "$(watch_fn "consider me o/r 7 '$HEAD1' url; consider me o/r 7 '$HEAD1' url" | grep -c 'not retried')" = 1 ]
}

case_approval_post_failure_stays_pending() {
  reset_state
  set_head "$HEAD1"
  FAKE_GH_POST_FAIL=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "approval POST failure: fakes answered" called "claude VALIDATOR"
  check "approval POST failure: pending for the sha" [ "$(cat "$KEY.approval-pending" 2>/dev/null)" = "$HEAD1" ]
  check "approval POST failure: body kept" [ -s "$KEY.approval-body" ]
}

case_verify_retry_skips_delta() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  export FAKE_DELTA_TEXT=$'no findings, nothing posted\nDELTA_FINDINGS 0\nDELTA_CONFIDENT value=true'
  FAKE_VERIFY_RC=1 run_review verify "$HEAD2" "$HEAD1"
  check "verify retry: first attempt failed" [ "$RC" != 0 ]
  FAKE_VERIFY_TEXT=$'all fixed\nVERIFY_VERDICT reviewed=2 reopened=0 regressions=0 complete=true confident=true\nCONFIDENCE fixed' \
    run_review verify "$HEAD2" "$HEAD1"
  unset FAKE_DELTA_TEXT
  check "verify retry: fakes answered" called "claude VERIFY"
  check "verify retry: delta not rerun" not_called "claude DELTA"
  check "verify retry: one approval" [ "$(approvals)" = 1 ]
}

argv_of() { grep "^claude $1 " "$FAKE_LOG" | tail -1; }

case_pass_caps_and_diagnostics() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  local role
  for role in QUALITY THERMO VALIDATOR; do
    check "caps: $role has the default turn cap" eval 'argv_of $role | grep -q -- "--max-turns 200 "'
    check "caps: $role has the default budget cap" eval 'argv_of $role | grep -q -- "--max-budget-usd 25 "'
    check "caps: $role runs with GIT_TERMINAL_PROMPT=0" eval 'argv_of $role | grep -q "GIT_TERMINAL_PROMPT=0 "'
  done
  check "diagnostics: usage line fields" grep -q 'claude_version=2.1.308 turns=1 subtype=success cost=0 denials=0' "$TMP_DIR/run.out"
  PR_REVIEW_MAX_TURNS=7 PR_REVIEW_MAX_BUDGET_USD=3 FAKE_VALIDATOR_RC=1 FAKE_VALIDATOR_STDERR="validator stderr tail" \
    FAKE_VALIDATOR_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "caps: env overrides the turn cap" eval 'argv_of VALIDATOR | grep -q -- "--max-turns 7 --max-budget-usd 3 "'
  check "diagnostics: a non-zero exit logs the stderr tail" grep -q '^validator stderr tail$' "$TMP_DIR/run.out"
  check "diagnostics: a failed pass does not approve" [ "$(approvals)" = 0 ]
}

case_tick_guards() {
  reset_state
  mkdir -p "$STATE/runs"
  : >"$FAKE_LOG"
  local started elapsed
  started="$(date +%s)"
  check "tick: a hung gh call dies at the timeout" eval '! FAKE_GH_SLEEP=5 PR_REVIEW_WATCH_GH_TIMEOUT=1 watch_fn "gh api user" >/dev/null'
  elapsed=$(( $(date +%s) - started ))
  check "tick: the hung call took under 4s" [ "$elapsed" -lt 4 ]
  : >"$FAKE_LOG"
  RC=0
  FAKE_CLAUDE_OLD=1 PR_REVIEW_WATCH_STATE_DIR="$STATE" /bin/bash "$SCRIPTS/pr-review-watch/watch.sh" || RC=$?
  FAKE_CLAUDE_OLD=1 PR_REVIEW_WATCH_STATE_DIR="$STATE" /bin/bash "$SCRIPTS/pr-review-watch/watch.sh" || true
  check "tick: an old claude stops the tick" rc_is 1
  check "tick: an old claude notifies once" [ "$(grep -c '^notify .*permission-prompts' "$FAKE_LOG")" = 1 ]
  check "tick: an old claude makes no gh call" not_called "gh "
  mkdir -p "$TMP_DIR/ro" && chmod 555 "$TMP_DIR/ro"
  check "lock: a read-only state dir gives up" eval '! watch_fn "acquire_lock \"$TMP_DIR/ro/lock\" watch" >/dev/null'
  chmod 755 "$TMP_DIR/ro"
}

cat >"$TMP_DIR/standin.sh" <<'STANDIN'
#!/bin/bash
sleep 30017 &
sleep 30017
STANDIN
cat >"$TMP_DIR/standin-traps.sh" <<'STANDIN'
#!/bin/bash
trap 'echo INT >>"$1"' INT
trap 'echo TERM >>"$1"' TERM
while :; do sleep 0.1; done
STANDIN
chmod +x "$TMP_DIR/standin.sh" "$TMP_DIR/standin-traps.sh"

survivors() { pgrep -f "$1" | tr '\n' ' '; }

signal_runner() {
  local runner
  perl -e '$SIG{INT} = "DEFAULT"; exec @ARGV' /bin/bash -c \
    ". '$SCRIPTS/pr-council-review/lib.sh'; run_with_timeout 60 '$TMP_DIR/standin.sh'" &
  runner=$!
  sleep 1
  kill "-$1" "$runner"
  wait "$runner" 2>/dev/null || true
  sleep 0.5
}

case_signals() {
  signal_runner INT
  check "signals: INT leaves no stand-in" [ -z "$(survivors 'sleep 30017')" ]
  signal_runner TERM
  check "signals: TERM leaves no stand-in" [ -z "$(survivors 'sleep 30017')" ]
  local started elapsed rc=0
  started="$(date +%s)"
  PR_REVIEW_STOP_GRACE=1 /bin/bash -c ". '$SCRIPTS/pr-council-review/lib.sh'; run_with_timeout 1 '$TMP_DIR/standin-traps.sh' '$TMP_DIR/signals.log'" 2>/dev/null || rc=$?
  elapsed=$(( $(date +%s) - started ))
  check "timeout: exit 124" [ "$rc" = 124 ]
  check "timeout: INT, then TERM, then KILL" [ "$(tr '\n' ' ' <"$TMP_DIR/signals.log")" = "INT TERM " ]
  check "timeout: no stand-in survives" [ -z "$(survivors standin-traps)" ]
  check "timeout: stopped within the grace periods" [ "$elapsed" -lt 6 ]
}

case_launchd_plist() {
  local plist="$HOME/Library/LaunchAgents/com.aguimard.pr-review-watch.plist"
  mkdir -p "$HOME/.claude/scripts"
  ln -sfn "$SCRIPTS/pr-review-watch" "$HOME/.claude/scripts/pr-review-watch"
  PR_REVIEW_WATCH_NO_LOAD=1 /bin/bash "$SCRIPTS/pr-review-watch/install.sh" >/dev/null
  if command -v plutil >/dev/null; then
    check "launchd: plist lints" plutil -lint -s "$plist"
  fi
  check "launchd: abandons the process group" eval "grep -A1 '<key>AbandonProcessGroup</key>' '$plist' | grep -q '<true/>'"
  check "launchd: PATH starts with ~/.local/bin" grep -q "<string>$HOME/.local/bin:/opt/homebrew/bin:" "$plist"
}

case_clean_council_approves
case_council_findings_wait
case_phase_a_denial_vetoes
case_verify_after_findings_approves
case_incomplete_reviews
case_ticketed_then_clean_delta_waits
case_watch_mode
case_next_attempt
case_approval_post_failure_stays_pending
case_verify_retry_skips_delta
case_pass_caps_and_diagnostics
case_tick_guards
case_signals
case_launchd_plist

if [ "$failures" -ne 0 ]; then
  printf 'PR review flow smoke test: %s failure(s)\n' "$failures"
  exit 1
fi
printf 'PR review flow smoke test: ok\n'
