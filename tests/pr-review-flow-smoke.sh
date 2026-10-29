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
unset XDG_CONFIG_HOME
export FAKE_DIR="$TMP_DIR/fake"
export FAKE_LOG="$FAKE_DIR/calls.log"
export FAKE_FIXTURES="$FIXTURES"
export GH_CONFIG_DIR="$TMP_DIR/gh-config" GH_TOKEN=invalid-flow-token GITHUB_TOKEN=invalid-flow-token
export GH_ENTERPRISE_TOKEN=invalid-flow-token GITHUB_ENTERPRISE_TOKEN=invalid-flow-token
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export PR_REVIEW_WATCH_COUNCIL="$SCRIPTS/pr-council-review/run.sh"
export PR_COUNCIL_CLAUDE="$HOME/.local/bin/claude" PR_COUNCIL_CODEX="$HOME/.local/bin/codex" PR_REVIEW_WATCH_LOG="$TMP_DIR/watch.log"
export PR_REVIEW_WATCH_CI_WAIT=0 PR_REVIEW_USAGE_LOG="$TMP_DIR/usage.log" PR_COUNCIL_VERIFY_SKILL=test-verify-fixes
mkdir -p "$TMPDIR" "$HOME/.local/bin" "$HOME/.claude/skills/thermo-nuclear-code-quality-review" "$FAKE_DIR" "$GH_CONFIG_DIR"
echo "thermo stub" >"$HOME/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md"

cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
printf 'gh %s\n' "$*" >>"$FAKE_LOG"
[ -z "${FAKE_GH_SLEEP:-}" ] || sleep "$FAKE_GH_SLEEP"
filter="" prev="" write=0 paginate=0
for arg in "$@"; do
  [ "$prev" = --jq ] && filter="$arg"
  [ "$prev" = --input ] && cp "$arg" "$FAKE_DIR/payload.json"
  case "$arg" in -f|-F|--input|-X|--method) write=1 ;; --paginate) paginate=1 ;; esac
  prev="$arg"
done
case "$1 $2" in
  "auth status") exit 0 ;;
  "api user")
    echo x >>"$FAKE_DIR/user-calls"
    [ -z "${FAKE_GH_USER_FAIL_FROM:-}" ] || [ "$(wc -l <"$FAKE_DIR/user-calls")" -lt "$FAKE_GH_USER_FAIL_FROM" ] || exit 1
    out='{"login":"me"}' ;;
  "pr view") [ -z "${FAKE_GH_VIEW_FAIL:-}" ] || exit 1; out="$(cat "$FAKE_DIR/pr.json")" ;;
  "pr checks") out='[{"bucket":"pass"}]' ;;
  "search prs") [ -z "${FAKE_GH_DISCOVERY_FAIL:-}" ] || exit 1; out="${FAKE_GH_SEARCH:-[]}" ;;
  "pr list") out="$(jq -c --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '[{number, author: {login: "me"}, url, createdAt: $now, reviews: [], headRefOid}]' "$FAKE_DIR/pr.json")" ;;
  "api graphql") out='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}}' ;;
  *)
    case "$*" in
      api*repos/*/pulls/*/reviews*)
        if [ "$write" = 1 ]; then
          printf 'POST %s\n' "$*" >>"$FAKE_DIR/posts.log"
          [ -z "${FAKE_GH_POST_FAIL:-}" ] || exit 1
          out='{"html_url":"https://github.invalid/o/r/pull/7#review"}'
        else
          out="${FAKE_GH_REVIEWS:-[]}"
          [ ! -f "$FAKE_DIR/phase-a-ran" ] || [ -z "${FAKE_GH_REVIEWS_MID:-}" ] || out="$FAKE_GH_REVIEWS_MID"
          [ ! -f "$FAKE_DIR/phasea-prompt.txt" ] || [ -z "${FAKE_GH_REVIEWS_AFTER:-}" ] || out="$FAKE_GH_REVIEWS_AFTER"
          [ "$paginate" = 0 ] || [ -z "${FAKE_GH_REVIEWS_PAGE2:-}" ] || out="$out$FAKE_GH_REVIEWS_PAGE2"
        fi ;;
      api*repos/*/issues/*/timeline*)
        [ -z "${FAKE_GH_DISCOVERY_SLEEP:-}" ] || sleep "$FAKE_GH_DISCOVERY_SLEEP"
        [ -z "${FAKE_GH_DISCOVERY_FAIL:-}" ] || exit 1
        out="${FAKE_GH_TIMELINE:-[]}" ;;
      api*repos/*/compare/*) [ -z "${FAKE_GH_DISCOVERY_FAIL:-}" ] || exit 1; out="diff --git a/f b/f" ;;
      api*repos/*/pulls/[0-9]*)
        pull="$*" pull="${pull#*repos/}" pull="${pull%% *}" pull="$FAKE_DIR/linked/${pull//\//_}.json"
        [ -z "${FAKE_GH_DISCOVERY_FAIL:-}" ] && [ -f "$pull" ] || exit 1
        out="$(cat "$pull")" ;;
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
  "The validator already reviewed"*) role=PHASEA_ONLY ;;
  /code-review*) role=QUALITY ;;
  *thermo-nuclear*) role=THERMO ;;
  "Incremental review"*) role=DELTA ;;
  /test-verify-fixes*|/file-verify-fixes*) role=VERIFY ;;
  "You are the automatic PR review agent"*) role=AUTOREVIEW ;;
  *) echo "fake claude: unknown prompt" >&2; exit 1 ;;
esac
printf 'claude %s GIT_TERMINAL_PROMPT=%s %s\n' "$role" "${GIT_TERMINAL_PROMPT:-unset}" "${flags[*]}" >>"$FAKE_LOG"
[ "$role" != VALIDATOR ] || printf '%s' "$prompt" >"$FAKE_DIR/validator-prompt.txt"
[ "$role" != VALIDATOR ] || { pwd -P; git rev-parse --show-toplevel HEAD; git remote get-url origin; cat .claude/settings.local.json; ls node_modules; } >"$FAKE_DIR/validator-cwd" 2>/dev/null
[ "$role" != PHASEA_ONLY ] || printf '%s' "$prompt" >"$FAKE_DIR/phasea-prompt.txt"
[ "$role" != VERIFY ] || printf '%s' "$prompt" >"$FAKE_DIR/verify-prompt.txt"
[ "$role" != DELTA ] || printf '%s' "$prompt" >"$FAKE_DIR/delta-prompt.txt"
[ "$role" != THERMO ] || printf '%s' "$prompt" >"$FAKE_DIR/thermo-prompt.txt"
[ "$role" != QUALITY ] || : >"$FAKE_DIR/phase-a-ran"
stderr_var="FAKE_${role}_STDERR"
[ -z "${!stderr_var:-}" ] || echo "${!stderr_var}" >&2
stream=0
case " ${flags[*]} " in *" stream-json "*) stream=1 ;; esac
[ "$stream" = 0 ] || echo '{"type":"system","subtype":"init"}'
interim_var="FAKE_${role}_INTERIM" ticks_var="FAKE_${role}_TICKS" noresult_var="FAKE_${role}_NORESULT"
[ -z "${!interim_var:-}" ] || echo "${!interim_var}"
for ((tick = 0; tick < ${!ticks_var:-0}; tick++)); do sleep 1; echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}'; done
sleep_var="FAKE_${role}_SLEEP"
[ -z "${!sleep_var:-}" ] || sleep "${!sleep_var}"
[ -z "${!noresult_var:-}" ] || exit 0
envelope_var="FAKE_${role}_ENVELOPE" text_var="FAKE_${role}_TEXT" rc_var="FAKE_${role}_RC" patch_var="FAKE_${role}_PATCH"
envelope="$FAKE_FIXTURES/2.1.308-${!envelope_var:-success}.json"
text="${!text_var:-}"
out="$(jq --arg t "${text//\{\{SHA\}\}/$FAKE_HEAD}" 'if (.result | type) == "string" and $t != "" then .result = $t else . end' "$envelope" | jq "${!patch_var:-.}")"
if [ "$stream" = 1 ]; then jq -c . <<<"$out"; else printf '%s\n' "$out"; fi
if [ -n "${!rc_var:-}" ]; then exit "${!rc_var}"; fi
[ "$(printf '%s' "$out" | jq -r .is_error)" = false ]
CLAUDE

cat >"$HOME/.local/bin/codex" <<'CODEX'
#!/bin/bash
printf 'codex %s\n' "${*:1:$#-1}" >>"$FAKE_LOG"
printf '%s' "${!#}" >"$FAKE_DIR/codex-prompt.txt"
prev="" out=""
for arg in "$@"; do
  [ "$prev" = --output-last-message ] && out="$arg"
  prev="$arg"
done
[ -z "${FAKE_CODEX_RC:-}" ] || exit "$FAKE_CODEX_RC"
printf '%s\n' "${FAKE_CODEX_TEXT:-codex: no defect found}" >"$out"
CODEX

cat >"$HOME/.local/bin/terminal-notifier" <<'NOTIFY'
#!/bin/bash
printf 'notify %s\n' "$*" >>"$FAKE_LOG"
[ -z "${FAKE_NOTIFY_TERM:-}" ] || kill -TERM "$PPID"
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
  local files='[{"path":"a.txt","additions":1,"deletions":0}]' author='{"login":"dev","is_bot":false}'
  files="${FAKE_PR_FILES:-$files}" author="${FAKE_PR_AUTHOR:-$author}"
  printf '{"number":7,"body":%s,"headRefOid":"%s","baseRefName":"main","url":"https://github.invalid/o/r/pull/7","title":"t","state":"OPEN","isDraft":false,"latestReviews":%s,"reviewRequests":[{"login":"me"}],"author":%s,"files":%s,"changedFiles":%s,"additions":%s,"deletions":0}' \
    "$(jq -n --arg b "${FAKE_PR_BODY:-}" '$b')" "$1" "${2:-[]}" "$author" "$files" \
    "$(printf '%s' "$files" | jq length)" "$(printf '%s' "$files" | jq 'map(.additions) | add')" >"$FAKE_DIR/pr.json"
}

marker() {
  printf '<!-- claudine:v1 {"kind":"run","run":"7-1-me","sha":"{{SHA}}","findings":%s,"floor":"major","suppressed":0,"security":"%s","lenses":["done"]} -->' \
    "$1" "${2:-none}"
}

delta_review() { printf '.structured_output = %s | .result = (.structured_output | tojson)' "$1"; }
export FAKE_DELTA_ENVELOPE=structured-output FAKE_DELTA_PATCH="$(delta_review '{"findings":[],"confident":true}')"

STATE="$TMP_DIR/state"
KEY="$STATE/runs/o_r_7"
RC=0

run_review() {
  mkdir -p "$STATE/runs"
  : >"$FAKE_LOG"
  : >"$FAKE_DIR/posts.log"
  rm -f "$FAKE_DIR/validator-prompt.txt" "$FAKE_DIR/phasea-prompt.txt" "$FAKE_DIR/phase-a-ran" "$FAKE_DIR/user-calls"
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

linked_pinned() {
  local prompt="$1" ref
  shift
  for ref in "$@"; do
    grep -qF "\`$ref\` at \`$(printf '%040d' "${ref##*#}")\`" "$prompt" || return 1
  done
}

case_linked_prs() {
  local prompt="$FAKE_DIR/validator-prompt.txt"
  pull() { printf '{"state":"%s","author_association":"%s","title":"%s","base":{"sha":"%040d"},"head":{"sha":"%040d"}}' "$1" "${4:-MEMBER}" "$2" 1 "$3"; }
  xref() { printf '{"event":"cross-referenced","source":{"issue":{"number":%s,"pull_request":{},"repository":{"full_name":"%s"}}}}' "$2" "$1"; }
  mkdir -p "$FAKE_DIR/linked"
  pull open "front fix" 11 >"$FAKE_DIR/linked/o_front_pulls_11.json"
  pull open "back fix" 12 >"$FAKE_DIR/linked/o_back_pulls_12.json"
  pull closed "old" 13 >"$FAKE_DIR/linked/o_closed_pulls_13.json"
  pull open "api fix" 14 >"$FAKE_DIR/linked/o_api_pulls_14.json"
  pull open "fork pr" 15 CONTRIBUTOR >"$FAKE_DIR/linked/o_front_pulls_15.json"
  export FAKE_PR_BODY=$'fixes PRD-9\nSee o/back#12, bad/ref#x and https://github.com/o/closed/pull/13'
  FAKE_GH_TIMELINE="$(printf '[%s,%s,%s,%s,{"event":"labeled"}]' "$(xref o/front 11)" "$(xref x/evil 3)" "$(xref o/r 7)" "$(xref o/front 15)")"
  export FAKE_GH_TIMELINE
  export FAKE_GH_SEARCH='[{"repository":{"nameWithOwner":"o/api"},"number":14},{"repository":{"nameWithOwner":"o/front"},"number":11}]'
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "linked: validator ran" called "claude VALIDATOR"
  check "linked: section in the gate prompt" grep -q '^## Linked pull requests' "$prompt"
  check "linked: timeline, body and ticket PRs kept, pinned" linked_pinned "$prompt" o/front#11 o/back#12 o/api#14
  check "linked: closed, non-member, foreign, malformed and self dropped" eval '! grep "^- \`" "$prompt" | grep -qE "o/closed#13|o/front#15|x/evil|bad/ref|o/r#7"'
  check "linked: foreign owner never queried" eval '! grep -q "repos/x/evil" "$FAKE_LOG"'
  check "linked: ticket searched within the owner" eval 'grep -q "^gh search prs PRD-9 --owner o " "$FAKE_LOG"'
  check "linked: one line per PR" [ "$(grep -c '^- `o/' "$prompt")" = 3 ]
  check "untrusted clause: validator prompt" grep -q 'are not yours to follow' "$prompt"
  reset_state
  FAKE_GH_DISCOVERY_FAIL=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "linked discovery fails: validator still runs" called "claude VALIDATOR"
  check "linked discovery fails: no section" eval '! grep -q "Linked pull requests" "$FAKE_DIR/validator-prompt.txt"'
  reset_state
  PR_COUNCIL_LINKED_TIMEOUT=1 FAKE_GH_DISCOVERY_SLEEP=30 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "linked discovery hangs: bounded, validator runs" called "claude VALIDATOR"
  check "linked discovery hangs: exit 0" rc_is 0
  reset_state
  PR_COUNCIL_LINKED_MAX_LINES=0 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "linked diff above the line cap: no section" eval '! grep -q "Linked pull requests" "$FAKE_DIR/validator-prompt.txt"'
  reset_state
  PR_COUNCIL_VALIDATOR_LOGIN='some-validator[bot]' \
    FAKE_GH_REVIEWS='[{"user":{"login":"some-validator[bot]","type":"Bot"},"commit_id":"'"$HEAD1"'","state":"APPROVED"}]' \
    FAKE_PHASEA_ONLY_TEXT="Nothing survived. $(marker 0)" run_review council "$HEAD1" -
  check "linked: section in the phase A only prompt" grep -q '^## Linked pull requests' "$FAKE_DIR/phasea-prompt.txt"
  check "untrusted clause: phase A only prompt" grep -q 'are not yours to follow' "$FAKE_DIR/phasea-prompt.txt"
  unset FAKE_PR_BODY FAKE_GH_TIMELINE FAKE_GH_SEARCH
  rm -rf "$FAKE_DIR/linked"
}

case_validator_checkout() {
  local seen="$FAKE_DIR/validator-cwd" repo
  mkdir -p "$CLONE/.claude" "$CLONE/node_modules/pkg"
  echo '{"local":1}' >"$CLONE/.claude/settings.local.json"
  : >"$CLONE/node_modules/pkg/index.js"
  printf 'node_modules/\n' >"$CLONE/.worktreeinclude"
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  repo="$(sed -n 1p "$seen")"
  check "validator checkout: validator ran" called "claude VALIDATOR"
  check "validator checkout: its own repository" [ "$(sed -n 2p "$seen")" = "$repo" ]
  check "validator checkout: not the user's checkout" [ "$repo" != "$(cd "$CLONE" && pwd -P)" ]
  check "validator checkout: at the user's head" [ "$(sed -n 3p "$seen")" = "$(git -C "$CLONE" rev-parse HEAD)" ]
  check "validator checkout: same origin" [ "$(sed -n 4p "$seen")" = "$(git -C "$CLONE" remote get-url origin)" ]
  check "validator checkout: local settings carried" [ "$(sed -n 5p "$seen")" = '{"local":1}' ]
  check "validator checkout: no ignored files" [ "$(wc -l <"$seen" | tr -d ' ')" = 5 ]
  check "validator checkout: removed after the run" no_file "$repo"
  rm -rf "$CLONE/.claude" "$CLONE/node_modules" "$CLONE/.worktreeinclude"
}

idle_setting() {
  PR_REVIEW_PASS_IDLE="$1" /bin/bash -c ". '$SCRIPTS/pr-council-review/lib.sh'; echo \"\$CLAUDE_PASS_IDLE\""
}

idle_run() {
  IDLE_FILE="$TMP_DIR/idle.stream" /bin/bash -c ". '$SCRIPTS/pr-council-review/lib.sh'; : >\"\$IDLE_FILE\"; run_with_timeout --idle $1 \"\$IDLE_FILE\" 10 /bin/bash -c '$2'" >/dev/null 2>&1
}

case_stalled_pass() {
  local interim
  interim="$(jq -c --arg t "Review posted. $(marker 0 | sed "s/{{SHA}}/$HEAD1/")" '.result = $t' "$FIXTURES/2.1.308-success.json")"
  reset_state
  set_head "$HEAD1"
  PR_REVIEW_PASS_IDLE=2 PR_REVIEW_STOP_GRACE=1 FAKE_VALIDATOR_INTERIM="$interim" FAKE_VALIDATOR_SLEEP=30 \
    FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "stall: reported" grep -q '^=== stalled: no session output for 2s' "$TMP_DIR/run.out"
  check "stall: last event named" grep -q '^=== validator: last session event result/success, last tool call none$' "$TMP_DIR/run.out"
  check "stall: exit 124 despite an earlier result" rc_is 124
  check "stall: no approval" [ "$(approvals)" = 0 ]
  check "stall: not recorded clean" no_file "$KEY.council-clean"
  reset_state
  PR_REVIEW_PASS_IDLE=2 PR_REVIEW_STOP_GRACE=1 FAKE_VALIDATOR_INTERIM="$(jq -c . "$FIXTURES/2.1.308-error-max-turns.json")" \
    FAKE_VALIDATOR_SLEEP=30 run_review council "$HEAD1" -
  check "stall after an incomplete result: exit 124, retried" rc_is 124
  reset_state
  PR_REVIEW_PASS_IDLE=2 FAKE_VALIDATOR_TICKS=5 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "active pass past the idle limit: not stopped" eval '! grep -q "stalled" "$TMP_DIR/run.out"'
  check "active pass past the idle limit: exit 0" rc_is 0
  check "idle 0: limit off" [ "$(idle_setting 0)" = 0 ]
  check "idle not an integer: default limit" [ "$(idle_setting x)" = 900 ]
  check "idle unset: default limit" [ "$(idle_setting '')" = 900 ]
  check "idle 0: a silent command runs to its end" idle_run 0 'sleep 2'
  check "idle 1: a silent command is stopped" eval '! idle_run 1 "sleep 4"'
  check "idle 1: writes 0.6 s apart are not a stall" idle_run 1 'for i in 1 2 3 4 5; do sleep 0.6; echo x >>"$IDLE_FILE"; done'
  reset_state
  FAKE_VALIDATOR_INTERIM="$interim" FAKE_VALIDATOR_ENVELOPE=error-max-turns run_review council "$HEAD1" -
  check "success then error: the last result wins" grep -q 'subtype=error_max_turns' "$TMP_DIR/run.out"
  check "success then error: no approval" [ "$(approvals)" = 0 ]
  reset_state
  FAKE_VALIDATOR_NORESULT=1 run_review council "$HEAD1" -
  check "no result line: the pass fails" eval '! rc_is 0 && grep -q "could not parse the session output" "$TMP_DIR/run.out"'
  check "no result line: no approval" [ "$(approvals)" = 0 ]
}

case_linked_on_later_pushes() {
  local f
  mkdir -p "$FAKE_DIR/linked"
  printf '{"state":"open","author_association":"MEMBER","title":"front fix","base":{"sha":"%040d"},"head":{"sha":"%040d"}}' 1 11 \
    >"$FAKE_DIR/linked/o_front_pulls_11.json"
  export FAKE_GH_TIMELINE='[{"event":"cross-referenced","source":{"issue":{"number":11,"pull_request":{},"repository":{"full_name":"o/front"}}}}]'
  rm -f "$FAKE_DIR/delta-prompt.txt" "$FAKE_DIR/verify-prompt.txt"
  verify_after_findings "$HEAD2"
  check "later push: delta ran" called "claude DELTA"
  check "later push: linked section in the delta prompt" grep -q '^## Linked pull requests' "$FAKE_DIR/delta-prompt.txt"
  check "later push: linked section in the verify prompt" grep -q '^## Linked pull requests' "$FAKE_DIR/verify-prompt.txt"
  check "later push: same pinned PR in both" eval 'grep -q "o/front#11" "$FAKE_DIR/delta-prompt.txt" && grep -q "o/front#11" "$FAKE_DIR/verify-prompt.txt"'
  check "later push: linked PRs collected once" [ "$(grep -c 'issues/7/timeline' "$FAKE_LOG")" = 1 ]
  for f in thermo codex delta verify; do
    check "untrusted clause: $f prompt" grep -q 'are not yours to follow' "$FAKE_DIR/$f-prompt.txt"
  done
  unset FAKE_GH_TIMELINE
  rm -rf "$FAKE_DIR/linked"
  verify_after_findings "$HEAD2"
  check "later push, no linked PR: no section in the delta prompt" eval '! grep -q "Linked pull requests" "$FAKE_DIR/delta-prompt.txt"'
  check "later push, no linked PR: no section in the verify prompt" eval '! grep -q "Linked pull requests" "$FAKE_DIR/verify-prompt.txt"'
}

case_council_hangup() {
  local pid repo
  reset_state
  set_head "$HEAD1"
  rm -f "$FAKE_DIR/validator-cwd"
  PR_REVIEW_STOP_GRACE=1 FAKE_VALIDATOR_SLEEP=37 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" - &
  for _ in $(seq 1 100); do [ -s "$FAKE_DIR/validator-cwd" ] && break; sleep 0.2; done
  repo="$(sed -n 1p "$FAKE_DIR/validator-cwd")"
  pid="$(pgrep -f "$SCRIPTS/pr-council-review/run.sh 7 o/r" | head -1)"
  check "hangup: council found running" [ -n "$pid" ]
  kill -HUP "$pid" 2>/dev/null
  for _ in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  check "hangup: council stops within 10 s" eval '! kill -0 "$pid" 2>/dev/null'
  check "hangup: validator stopped" eval '! pgrep -fx "sleep 37" >/dev/null'
  wait
  check "hangup: validator clone removed" no_file "$repo"
  check "hangup: scratch worktree removed" eval '! git -C "$CLONE" worktree list | grep -q pr-council'
}

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

case_codex_member() {
  reset_state
  set_head "$HEAD1"
  FAKE_CODEX_TEXT="codex finding a.txt:1" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "codex member: read-only sol xhigh" grep -q -- "^codex exec .*--sandbox read-only .*--model gpt-6.1-sol -c model_reasoning_effort=\"xhigh\"" "$FAKE_LOG"
  check "codex member: report reaches the validator" grep -q "cross-family member" "$FAKE_DIR/validator-prompt.txt"
  check "codex member: exit 0" rc_is 0
  reset_state
  FAKE_CODEX_RC=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "codex failure: validator still runs" called "claude VALIDATOR"
  check "codex failure: same-family" grep -q "Phase A was same-family" "$FAKE_DIR/validator-prompt.txt"
  check "codex failure: exit 0" rc_is 0
  reset_state
  PR_COUNCIL_USE_CODEX=0 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "codex opt-out: not called" not_called codex
  check "codex opt-out: same-family" grep -q "Phase A was same-family" "$FAKE_DIR/validator-prompt.txt"
  check "codex opt-out: exit 0" rc_is 0
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
  check "phase A denial: one notification" [ "$(grep -c '^notify ' "$FAKE_LOG")" = 1 ]
}

case_unverified_envelopes() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" FAKE_VALIDATOR_PATCH='.permission_denials = {}' run_review council "$HEAD1" -
  check "denials as an object: fakes answered" called "claude VALIDATOR"
  check "denials as an object: vetoed" rc_is 3
  check "denials as an object: no approval" [ "$(approvals)" = 0 ]
  reset_state
  FAKE_VALIDATOR_PATCH=empty FAKE_VALIDATOR_RC=1 run_review council "$HEAD1" -
  check "empty output: fakes answered" called "claude VALIDATOR"
  check "empty output: retryable failure, not incomplete" rc_is 1
  reset_state
  FAKE_VALIDATOR_PATCH=empty FAKE_VALIDATOR_RC=0 run_review council "$HEAD1" -
  check "empty output with exit 0: retryable failure, not a veto" rc_is 1
}

case_verify_after_findings_approves() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
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

unwatch_as() {
  printf 'o/r\t7\n' >"$STATE/watched.tsv"
  echo "$HEAD1" >"$KEY.council-done"
  watch_fn "pr_snapshot() { printf '$1\tfalse\t$HEAD1\turl\t$2\t$3\n'; }; herdr_available() { return 1; }; remove_finished_clones() { :; }; process_watched me" >/dev/null
}

case_unwatch_state() {
  reset_state
  mkdir -p "$STATE/runs"
  unwatch_as CLOSED true false
  check "unwatch: a closed PR drops its run state" no_file "$KEY.council-done"
  unwatch_as OPEN true true
  check "unwatch: an approved open PR keeps its run state" [ -f "$KEY.council-done" ]
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
  rm -f "$KEY.exhausted"
  attempt_after 1 3 "$old" >/dev/null
  check "attempt: an exhausted sha is logged once" [ "$(watch_fn "consider me o/r 7 '$HEAD1' url; consider me o/r 7 '$HEAD1' url" | grep -c 'giving up')" = 1 ]
}

case_verify_skill_config() {
  local conf="$HOME/.config/pr-council-review/verify-skill" old=202001010000
  reset_state
  rm -f "$conf"
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  export FAKE_VERIFY_TEXT=$'all fixed\nVERIFY_VERDICT reviewed=2 reopened=0 regressions=0 complete=true confident=true\nCONFIDENCE fixed'
  PR_COUNCIL_VERIFY_SKILL='' run_review verify "$HEAD2" "$HEAD1"
  check "verify unconfigured: own exit code" rc_is 5
  check "verify unconfigured: reported" grep -q "verify: unconfigured" "$TMP_DIR/run.out"
  check "verify unconfigured: no verify pass" not_called "claude VERIFY"
  check "verify unconfigured: no watermark" no_file "$KEY.watermark"
  check "verify unconfigured: no approval" [ "$(approvals)" = 0 ]
  check "verify unconfigured: marker names the sha" [ "$(cat "$KEY.verify-unconfigured" 2>/dev/null)" = "$HEAD2" ]
  printf '%s\n' "$HEAD1" >"$KEY.verify-unconfigured"
  check "verify unconfigured: the watcher waits" [ "$(PR_COUNCIL_VERIFY_SKILL='' attempt_after 5 1 "$old")" = unconfigured ]
  check "verify unconfigured: no attempt spent once configured" [ "$(attempt_after 5 1 "$old")" = 1 ]
  check "verify unconfigured: resumes at the cap once configured" [ "$(attempt_after 5 3 "$old")" = 3 ]
  rm -f "$KEY.verify-unconfigured"
  check "rc 5 without the marker spends the cap" [ "$(attempt_after 5 3 "$old")" = exhausted ]
  check "rc 5 without the marker, skill missing, retries" [ "$(PR_COUNCIL_VERIFY_SKILL='' attempt_after 5 1 "$old")" = 2 ]
  printf '%s\n' "$HEAD1" >"$KEY.verify-unconfigured"
  run_review verify "$HEAD2" "$HEAD1"
  check "verify configured later: same sha verified" called "claude VERIFY"
  check "verify configured later: marker cleared" no_file "$KEY.verify-unconfigured"
  check "verify configured later: watermark" [ "$(cat "$KEY.watermark" 2>/dev/null)" = "$HEAD2" ]
  check "verify configured later: one approval" [ "$(approvals)" = 1 ]
  mkdir -p "$(dirname "$conf")"
  printf 'file-verify-fixes\n' >"$conf"
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  PR_COUNCIL_VERIFY_SKILL='' run_review verify "$HEAD2" "$HEAD1"
  check "verify skill from file" grep -q "^/file-verify-fixes 7 o/r" "$FAKE_DIR/verify-prompt.txt"
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  run_review verify "$HEAD2" "$HEAD1"
  check "verify skill: env wins over file" grep -q "^/test-verify-fixes 7 o/r" "$FAKE_DIR/verify-prompt.txt"
  printf '%s\n' "$HEAD1" >"$KEY.verify-unconfigured"
  printf 'bad name!\n' >"$conf"
  check "verify skill: malformed file is unconfigured" [ "$(PR_COUNCIL_VERIFY_SKILL='' attempt_after 5 1 "$old")" = unconfigured ]
  printf 'test-verify -fixes\n' >"$conf"
  check "verify skill: inner whitespace is unconfigured" [ "$(PR_COUNCIL_VERIFY_SKILL='' attempt_after 5 1 "$old")" = unconfigured ]
  printf '  /file-verify-fixes  \n' >"$conf"
  check "verify skill: outer whitespace and slash are trimmed" [ "$(PR_COUNCIL_VERIFY_SKILL='' attempt_after 5 1 "$old")" = 1 ]
  rm -f "$conf"
  unset FAKE_VERIFY_TEXT
}

case_approval_post_failure_stays_pending() {
  reset_state
  set_head "$HEAD1"
  FAKE_GH_POST_FAIL=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "approval POST failure: fakes answered" called "claude VALIDATOR"
  check "approval POST failure: pending for the sha" [ "$(cat "$KEY.approval-pending" 2>/dev/null)" = "$HEAD1" ]
  check "approval POST failure: body kept" [ -s "$KEY.approval-body" ]
  rm -f "$KEY.approval-pending" "$KEY.approval-body"
  FAKE_NOTIFY_TERM=1 FAKE_GH_POST_FAIL=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "approval POST failure then TERM: still pending" [ "$(cat "$KEY.approval-pending" 2>/dev/null)" = "$HEAD1" ]
  FAKE_GH_POST_FAIL=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  FAKE_GH_POST_FAIL=1 run_review approve "$HEAD1" -
  check "approval POST failure again: no second notification" not_called "notify "
  run_review approve "$HEAD1" -
  check "pending approval: approved" [ "$(approvals)" = 1 ]
  check "pending approval: no model call" not_called "claude "
  check "pending approval: cleared" no_file "$KEY.approval-pending"
}

case_verify_retry_skips_delta() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$HEAD2" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  FAKE_VERIFY_RC=1 run_review verify "$HEAD2" "$HEAD1"
  check "verify retry: first attempt failed" [ "$RC" != 0 ]
  FAKE_VERIFY_TEXT=$'all fixed\nVERIFY_VERDICT reviewed=2 reopened=0 regressions=0 complete=true confident=true\nCONFIDENCE fixed' \
    run_review verify "$HEAD2" "$HEAD1"
  check "verify retry: fakes answered" called "claude VERIFY"
  check "verify retry: delta not rerun" not_called "claude DELTA"
  check "verify retry: one approval" [ "$(approvals)" = 1 ]
}

argv_of() { grep "^claude $1 " "$FAKE_LOG" | tail -1; }

verify_after_findings() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$1" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  FAKE_VERIFY_TEXT=$'all fixed\nVERIFY_VERDICT reviewed=2 reopened=0 regressions=0 complete=true confident=true\nCONFIDENCE fixed' \
    run_review verify "$1" "$HEAD1"
}

case_delta_structured() {
  FAKE_DELTA_PATCH="$(delta_review '{"findings":[{"path":"a.txt","line":2,"body":"two is wrong"},{"path":"m.py","line":9,"body":"outside the diff"}],"confident":false}')" \
    verify_after_findings "$HEAD2"
  check "delta: fakes answered" called "claude DELTA"
  check "delta: read-only profile" eval 'argv_of DELTA | grep -q -- "--permission-mode auto --permission-prompts none --disallowedTools=Edit,Write,NotebookEdit "'
  check "delta: no bypass" eval '! argv_of DELTA | grep -q -- --dangerously-skip-permissions'
  check "delta: json schema" eval 'argv_of DELTA | grep -q -- "--json-schema "'
  check "delta: low effort" eval 'argv_of DELTA | grep -q -- "--effort low "'
  check "delta: the script posts the anchored finding" jq -e --arg sha "$HEAD2" \
    '.event == "COMMENT" and .commit_id == $sha and .comments == [{"path":"a.txt","line":2,"side":"RIGHT","body":"two is wrong"}]' "$FAKE_DIR/payload.json"
  check "delta: an unanchored finding goes to the body" eval 'jq -r .body "$FAKE_DIR/payload.json" | grep -q "m.py.*outside the diff"'
  check "delta: findings counted" grep -q '^DELTA_FINDINGS 2$' "$TMP_DIR/run.out"
  check "delta: no approval" [ "$(approvals)" = 0 ]
  check "delta: the prompt does not post" eval '! grep -q "gh api" "$SCRIPTS/pr-review-watch/delta-prompt.md"'
  FAKE_DELTA_PATCH='.structured_output = null' verify_after_findings "$HEAD2"
  check "delta: no structured output is incomplete" rc_is 4
  check "delta: no structured output does not approve" [ "$(approvals)" = 0 ]
}

case_validator_profile() {
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  check "validator: fakes answered" called "claude VALIDATOR"
  check "validator: auto profile" eval 'argv_of VALIDATOR | grep -q -- "--permission-mode auto --permission-prompts none "'
  check "validator: only the review POST is pre-allowed" eval 'argv_of VALIDATOR | grep -qF -- "--allowedTools Bash(gh api repos/o/r/pulls/7/reviews:*) "'
  check "validator: no bypass" eval '! argv_of VALIDATOR | grep -q -- --dangerously-skip-permissions'
  FAKE_VALIDATOR_ENVELOPE=denied FAKE_VALIDATOR_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "validator: a denial vetoes" rc_is 3
  check "validator: a denial does not approve" [ "$(approvals)" = 0 ]
}

case_delta_same_patch_skips() {
  git -C "$TMP_DIR/seed" checkout -q main
  echo base2 >"$TMP_DIR/seed/b.txt"
  git -C "$TMP_DIR/seed" add b.txt
  git -C "$TMP_DIR/seed" commit -q -m base2
  git -C "$TMP_DIR/seed" push -q "$TMP_DIR/origin.git" main
  git -C "$TMP_DIR/seed" checkout -q -b rebased
  git -C "$TMP_DIR/seed" cherry-pick "$HEAD1" >/dev/null
  local rebased
  rebased="$(git -C "$TMP_DIR/seed" rev-parse HEAD)"
  git -C "$TMP_DIR/seed" checkout -q feature
  verify_after_findings "$rebased"
  check "same patch: fakes answered" called "claude VERIFY"
  check "same patch: nothing new" grep -q '^=== nothing new since' "$TMP_DIR/run.out"
  check "same patch: no delta model call" not_called "claude DELTA"
}

autoreview() {
  : >"$FAKE_LOG"
  RC=0
  (cd "$CLONE" && /bin/bash "$SCRIPTS/pr-autoreview/run.sh" o/r agent-nodejs feature "$HEAD1" "$CLONE") || RC=$?
  cp "$HOME/.claude/logs/pr-autoreview.log" "$TMP_DIR/run.out"
}

case_autoreview_fails_loudly() {
  set_head "$HEAD1"
  FAKE_AUTOREVIEW_ENVELOPE=denied autoreview
  check "autoreview denial: fakes answered" called "claude AUTOREVIEW"
  check "autoreview denial: exits non-zero" [ "$RC" != 0 ]
  check "autoreview denial: notifies" called "notify "
  PR_AUTOREVIEW_TIMEOUT=1 PR_REVIEW_STOP_GRACE=1 FAKE_AUTOREVIEW_SLEEP=20 autoreview
  check "autoreview timeout: exits non-zero" [ "$RC" != 0 ]
  check "autoreview timeout: notifies" called "notify "
  autoreview
  check "autoreview without DONE: fakes answered" called "claude AUTOREVIEW"
  check "autoreview without DONE: exits non-zero" [ "$RC" != 0 ]
  check "autoreview without DONE: notifies" called "notify "
}

case_housekeeping() {
  local repo="$TMP_DIR/neutralize" stale="$TMPDIR/pr-verify-99.stale"
  git init -q "$repo"
  git -C "$repo" commit -q --allow-empty -m base
  mkdir -p "$repo/sub"
  echo steer >"$repo/CLAUDE.local.md"
  echo steer >"$repo/sub/CLAUDE.local.md"
  echo steer >"$repo/sub/AGENTS.override.md"
  mkdir -p "$repo/.codex"
  echo steer >"$repo/.codex/config.toml"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m steer
  /bin/bash -c ". '$SCRIPTS/pr-council-review/lib.sh'; neutralize_author_config '$repo' HEAD~1" >/dev/null
  check "author config: CLAUDE.local.md files are reset" eval '[ ! -e "$repo/CLAUDE.local.md" ] && [ ! -e "$repo/sub/CLAUDE.local.md" ]'
  check "author config: codex instructions are reset" eval '[ ! -e "$repo/sub/AGENTS.override.md" ] && [ ! -e "$repo/.codex/config.toml" ]'
  mkdir -p "$stale"
  touch -t 202001010000 "$stale"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" verify_after_findings "$HEAD2"
  check "purge: old verify dirs are removed" no_file "$stale"
  reset_state
  mkdir -p "$STATE"
  head -c 6000000 /dev/zero >"$PR_REVIEW_WATCH_LOG"
  PR_REVIEW_WATCH_STATE_DIR="$STATE" /bin/bash "$SCRIPTS/pr-review-watch/watch.sh" >/dev/null 2>&1 || true
  check "log: a large watch log is rotated" eval '[ -s "$PR_REVIEW_WATCH_LOG.1" ] && [ "$(wc -c <"$PR_REVIEW_WATCH_LOG")" -lt 6000000 ]'
}

case_verify_codes_propagate() {
  FAKE_VERIFY_ENVELOPE=denied verify_after_findings "$HEAD2"
  check "verify denial: fakes answered" called "claude VERIFY"
  check "verify denial: veto exit" rc_is 3
  FAKE_VERIFY_ENVELOPE=error-max-turns verify_after_findings "$HEAD2"
  check "verify cap hit: review-incomplete exit" rc_is 4
}

case_force_push_reruns_council() {
  git -C "$TMP_DIR/seed" checkout -q -b other main
  echo other >"$TMP_DIR/seed/c.txt"
  git -C "$TMP_DIR/seed" add c.txt
  git -C "$TMP_DIR/seed" commit -q -m other
  local other
  other="$(git -C "$TMP_DIR/seed" rev-parse HEAD)"
  git -C "$TMP_DIR/seed" checkout -q feature
  reset_state
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" run_review council "$HEAD1" -
  set_head "$other" '[{"state":"COMMENTED","author":{"login":"me"}}]'
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 1)" run_review verify "$other" "$HEAD1"
  check "force-push: the council runs again" called "claude VALIDATOR"
  check "force-push: no delta on unrelated history" not_called "claude DELTA"
  check "force-push: council recorded for the new head" [ "$(cat "$KEY.council-done" 2>/dev/null)" = "$other" ]
}

case_patch_id_failure_reviews() {
  local blob broken="$TMP_DIR/clone-broken" saved="$CLONE"
  verify_after_findings "$HEAD2" >/dev/null
  git clone -q --no-hardlinks "$TMP_DIR/origin.git" "$broken"
  git -C "$broken" fetch -q origin "+refs/pull/7/head:refs/remotes/origin/pr/7"
  for blob in $(git -C "$broken" rev-parse "$HEAD1:a.txt" "$HEAD2:a.txt"); do
    rm -f "$broken/.git/objects/${blob:0:2}/${blob:2}"
  done
  check "patch-id failure: the blobs are gone" eval '! git -C "$broken" cat-file -e "$HEAD1:a.txt" 2>/dev/null'
  rm -f "$KEY.delta-done"
  CLONE="$broken"
  run_review verify "$HEAD2" "$HEAD1"
  CLONE="$saved"
  check "patch-id failure: not taken as nothing new" eval '! grep -q "^=== nothing new since" "$TMP_DIR/run.out"'
  check "patch-id failure: no approval" [ "$(approvals)" = 0 ]
}

watch_decision() {
  reset_state
  mkdir -p "$STATE/runs"
  set_head "$HEAD2"
  : >"$FAKE_LOG"
  watch_fn "consider me o/r 7 '$HEAD2' url"
}

case_watch_skips() {
  local out
  out="$(FAKE_PR_AUTHOR='{"login":"dependabot[bot]","is_bot":true}' watch_decision)"
  check "skip: fakes answered" called "gh pr view"
  check "skip: a bot author is not reviewed" eval 'grep -q "bot author" <<<"$out" && ! grep -q "^launch" <<<"$out"'
  out="$(FAKE_PR_FILES='[{"path":"web/package-lock.json","additions":40,"deletions":0}]' watch_decision)"
  check "skip: a lockfile-only diff is not reviewed" eval 'grep -q "lockfile-only" <<<"$out" && ! grep -q "^launch" <<<"$out"'
  out="$(FAKE_PR_FILES='[{"path":"README.md","additions":4,"deletions":0},{"path":"docs/a.rst","additions":2,"deletions":0}]' watch_decision)"
  check "skip: a docs-only diff is not reviewed" eval 'grep -q "docs-only" <<<"$out" && ! grep -q "^launch" <<<"$out"'
  out="$(FAKE_PR_FILES='[{"path":"a.txt","additions":1,"deletions":0},{"path":"yarn.lock","additions":9000,"deletions":0}]' PR_REVIEW_WATCH_MAX_DIFF_LINES=10 watch_decision)"
  check "skip: lockfile lines do not count toward the size cap" grep -q "^launch council" <<<"$out"
  out="$(FAKE_GH_VIEW_FAIL=1 watch_decision)"
  check "skip: a failed size lookup is not reviewed" eval 'grep -q "size lookup failed" <<<"$out" && ! grep -q "^launch" <<<"$out"'
}

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
  mkdir -p "$TMP_DIR/fresh-lock"
  check "lock: a fresh lock without a pid is not stolen" eval '! watch_fn "acquire_lock \"$TMP_DIR/fresh-lock\" watch" >/dev/null'
  touch -t 202001010000 "$TMP_DIR/fresh-lock"
  check "lock: an old lock without a pid is taken" eval 'watch_fn "acquire_lock \"$TMP_DIR/fresh-lock\" watch" >/dev/null'
  chmod 755 "$TMP_DIR/ro"
}

case_phase_a_only() {
  local review label reviews page2
  review() { printf '{"user":{"login":"%s","type":"%s"},"commit_id":"%s","state":"%s"}' "$1" "$2" "$3" "$4"; }
  export PR_COUNCIL_VALIDATOR_LOGIN=some-validator[bot]
  reset_state
  set_head "$HEAD1"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing survived. $(marker 0)" run_review council "$HEAD1" -
  check "phase A only: validator not run" not_called "claude VALIDATOR"
  check "phase A only: verify pass runs on opus high" eval 'grep "^claude PHASEA_ONLY" "$FAKE_LOG" | grep -q -- "--model opus --effort high"'
  check "phase A only: phase A on opus high" eval 'grep "^claude QUALITY" "$FAKE_LOG" | grep -q -- "--model opus --effort high"'
  check "phase A only: exit 0" rc_is 0
  check "phase A only: one watcher approval" [ "$(approvals)" = 1 ]
  check "phase A only: recorded clean" [ "$(cat "$KEY.council-clean" 2>/dev/null)" = "$HEAD1" ]
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing new. $(marker 0)" run_review council "$HEAD1" -
  check "validator comment stands: no approval" [ "$(approvals)" = 0 ]
  check "validator comment stands: not clean" no_file "$KEY.council-clean"
  check "validator comment stands: done" [ "$(cat "$KEY.council-done" 2>/dev/null)" = "$HEAD1" ]
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED),$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "validator approved after commenting: one approval" [ "$(approvals)" = 1 ]
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_AFTER="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing new. $(marker 0)" run_review council "$HEAD1" -
  check "validator commented during the run: no approval" [ "$(approvals)" = 0 ]
  check "validator commented during the run: not clean" no_file "$KEY.council-clean"
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_AFTER="[$(review some-validator[bot] Bot "$HEAD1" DISMISSED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing new. $(marker 0)" run_review council "$HEAD1" -
  check "validator approval dismissed during the run: no approval" [ "$(approvals)" = 0 ]
  check "validator approval dismissed during the run: not clean" no_file "$KEY.council-clean"
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_AFTER="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review me User "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Posted. $(marker 1)" run_review council "$HEAD1" -
  check "phase A only with findings: no approval" [ "$(approvals)" = 0 ]
  check "phase A only with findings: done" [ "$(cat "$KEY.council-done" 2>/dev/null)" = "$HEAD1" ]
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review me User "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Submission failed. $(marker 1)" run_review council "$HEAD1" -
  check "only an older review of ours: retryable failure" rc_is 1
  check "only an older review of ours: not done" no_file "$KEY.council-done"
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_MID="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review me User "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Submission failed. $(marker 1)" run_review council "$HEAD1" -
  check "review of ours posted during phase A: retryable failure" rc_is 1
  check "review of ours posted during phase A: not done" no_file "$KEY.council-done"
  reset_state
  FAKE_GH_USER_FAIL_FROM=2 FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "unreadable gh login: retryable failure" rc_is 1
  check "unreadable gh login: no verify pass" not_called "claude PHASEA_ONLY"
  check "unreadable gh login: reported by the council" eval 'grep -q "cannot read the gh login" "$TMP_DIR/run.out"'
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="Submission failed. $(marker 1)" run_review council "$HEAD1" -
  check "findings kept but not posted: retryable failure" rc_is 1
  check "findings kept but not posted: not done" no_file "$KEY.council-done"
  for label in "old head" "other bot" "similar bot" "dismissed" "pending"; do
    case "$label" in
      "old head") reviews="[$(review some-validator[bot] Bot "$HEAD2" COMMENTED)]" ;;
      "other bot") reviews="[$(review other[bot] Bot "$HEAD1" APPROVED)]" ;;
      "similar bot") reviews="[$(review openapi-validator[bot] Bot "$HEAD1" APPROVED)]" ;;
      dismissed) reviews="[$(review some-validator[bot] Bot "$HEAD1" DISMISSED)]" ;;
      pending) reviews="[$(review some-validator[bot] Bot "$HEAD1" PENDING)]" ;;
    esac
    reset_state
    FAKE_GH_REVIEWS="$reviews" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
    check "$label: validator runs" called "claude VALIDATOR"
    check "$label: no phase A only" not_called "claude PHASEA_ONLY"
  done
  reset_state
  page2="[$(review some-validator[bot] Bot "$HEAD1" CHANGES_REQUESTED)]"
  FAKE_GH_REVIEWS="[$(review dev User "$HEAD1" COMMENTED)]" FAKE_GH_REVIEWS_PAGE2="$page2" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "second page: phase A only" called "claude PHASEA_ONLY"
  reset_state
  PR_COUNCIL_PHASE_A_ONLY=0 FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "forced validator: validator runs" called "claude VALIDATOR"
  reset_state
  PR_COUNCIL_PHASE_A_ONLY=1 FAKE_PHASEA_ONLY_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "forced phase A only: no validator" not_called "claude VALIDATOR"
  check "forced phase A only: reviews still listed" called "gh api --paginate"
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" FAKE_PHASEA_ONLY_TEXT="Nothing survived." \
    run_review council "$HEAD1" -
  check "phase A only without marker: incomplete" eval 'grep -q "no validator run marker" "$TMP_DIR/run.out"'
  check "phase A only without marker: no approval" [ "$(approvals)" = 0 ]
  unset PR_COUNCIL_VALIDATOR_LOGIN
  mkdir -p "$HOME/.config/pr-council-review"
  echo some-validator[bot] >"$HOME/.config/pr-council-review/validator-login"
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" run_review council "$HEAD1" -
  check "login from config file: phase A only" called "claude PHASEA_ONLY"
  rm -f "$HOME/.config/pr-council-review/validator-login"
  reset_state
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" run_review council "$HEAD1" -
  check "no login: validator runs" called "claude VALIDATOR"
  check "no login: reviews not listed" not_called "gh api --paginate"
  reset_state
  PR_COUNCIL_PHASE_A_ONLY=1 run_review council "$HEAD1" -
  check "no login, forced phase A only: usage error" rc_is 2
  check "no login, forced phase A only: no model call" not_called "claude"
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
case_codex_member
case_phase_a_denial_vetoes
case_verify_after_findings_approves
case_incomplete_reviews
case_unverified_envelopes
case_ticketed_then_clean_delta_waits
case_watch_mode
case_unwatch_state
case_next_attempt
case_verify_skill_config
case_approval_post_failure_stays_pending
case_verify_retry_skips_delta
case_delta_structured
case_validator_profile
case_delta_same_patch_skips
case_verify_codes_propagate
case_force_push_reruns_council
case_patch_id_failure_reviews
case_watch_skips
case_autoreview_fails_loudly
case_housekeeping
case_pass_caps_and_diagnostics
case_tick_guards
case_launchd_plist
case_phase_a_only
case_linked_prs
case_validator_checkout
case_stalled_pass
case_linked_on_later_pushes
case_council_hangup

if [ "$failures" -ne 0 ]; then
  printf 'PR review flow smoke test: %s failure(s)\n' "$failures"
  exit 1
fi
printf 'PR review flow smoke test: ok\n'
