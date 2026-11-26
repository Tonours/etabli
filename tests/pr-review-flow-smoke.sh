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
LEAN_DENY='Workflow,ListAgents,ShareOnboardingGuide,Agent(Explore),Agent(Plan),Agent(statusline-setup)'
export FORCE_PROMPT_CACHING_5M=inherited ENABLE_CLAUDEAI_MCP_SERVERS=inherited
export FAKE_FIXTURES="$FIXTURES"
export GH_CONFIG_DIR="$TMP_DIR/gh-config" GH_TOKEN=invalid-flow-token GITHUB_TOKEN=invalid-flow-token
export GH_ENTERPRISE_TOKEN=invalid-flow-token GITHUB_ENTERPRISE_TOKEN=invalid-flow-token
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export PR_COUNCIL_CLAUDE="$HOME/.local/bin/claude" PR_COUNCIL_CODEX="$HOME/.local/bin/codex"
export PR_REVIEW_USAGE_LOG="$TMP_DIR/usage.log"
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
    out="$(jq -cn --arg login "${FAKE_GH_LOGIN:-me}" '{login:$login}')" ;;
  "pr view") [ -z "${FAKE_GH_VIEW_FAIL:-}" ] || exit 1; out="$(cat "$FAKE_DIR/pr.json")"
    if [ -n "${FAKE_DELTA_HEAD:-}" ] && [[ "$*" == *"--json headRefOid,baseRefName,url"* ]]; then
      out="$(jq --arg sha "$FAKE_DELTA_HEAD" '.headRefOid = $sha' <<<"$out")"
    fi ;;
  "pr checks") out='[{"bucket":"pass"}]' ;;
  "search prs") [ -z "${FAKE_GH_DISCOVERY_FAIL:-}" ] || exit 1; out="${FAKE_GH_SEARCH:-[]}" ;;
  "pr list") out="$(jq -c --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '[{number, author: {login: "me"}, url, createdAt: $now, reviews: [], headRefOid, baseRefName}]' "$FAKE_DIR/pr.json")" ;;
  "api graphql") out='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}}' ;;
  *)
    case "$*" in
      api*repos/*/pulls/*/reviews*)
        if [ "$write" = 1 ]; then
          printf 'POST %s\n' "$*" >>"$FAKE_DIR/posts.log"
          if [ -n "${FAKE_GH_POST_FAIL:-}" ]; then
            [ "$FAKE_GH_POST_FAIL" != 422 ] || printf 'HTTP/2.0 422 Unprocessable Entity\r\n\r\n{"message":"cannot approve"}\n'
            exit 1
          fi
          [[ " $* " != *" --include "* ]] || printf 'HTTP/2.0 200 OK\r\n\r\n'
          out='{"html_url":"https://github.invalid/o/r/pull/7#review"}'
        else
          echo x >>"$FAKE_DIR/review-reads"
          reads="$(wc -l <"$FAKE_DIR/review-reads" | tr -d ' ')"
          [ "$reads" != "${FAKE_GH_REVIEWS_FAIL_AT:-0}" ] || exit 1
          [ -z "${FAKE_GH_REVIEWS_FAIL_FROM:-}" ] || [ "$reads" -lt "$FAKE_GH_REVIEWS_FAIL_FROM" ] || exit 1
          out="${FAKE_GH_REVIEWS:-[]}"
          [ ! -f "$FAKE_DIR/phase-a-ran" ] || [ -z "${FAKE_GH_REVIEWS_MID:-}" ] || out="$FAKE_GH_REVIEWS_MID"
          [ ! -f "$FAKE_DIR/phasea-prompt.txt" ] || [ -z "${FAKE_GH_REVIEWS_AFTER:-}" ] || out="$FAKE_GH_REVIEWS_AFTER"
          [ ! -f "$FAKE_DIR/validator-prompt.txt" ] || [ -z "${FAKE_GH_POSTED_REVIEWS:-}" ] || out="$FAKE_GH_POSTED_REVIEWS"
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
  /test-verify-fixes*|/file-verify-fixes*|/acme:verify-fixes*) role=VERIFY ;;
  "You are the automatic PR review agent"*) role=AUTOREVIEW ;;
  *) echo "fake claude: unknown prompt" >&2; exit 1 ;;
esac
printf 'claude %s GIT_TERMINAL_PROMPT=%s %s\n' "$role" "${GIT_TERMINAL_PROMPT:-unset}" "${flags[*]}" >>"$FAKE_LOG"
deny='' settings=0
for arg in "${flags[@]}"; do
  case "$arg" in
    --disallowedTools=*|--disallowed-tools=*) deny="$deny|${arg#*=}" ;;
    --disallowedTools|--disallowed-tools) deny="$deny|bare-variadic-form" ;;
    --settings|--settings=*) settings=$((settings + 1)) ;;
  esac
done
printf '%s FORCE_PROMPT_CACHING_5M=%s ENABLE_CLAUDEAI_MCP_SERVERS=%s settings=%s deny=%s\n' "$role" \
  "${FORCE_PROMPT_CACHING_5M:-unset}" "${ENABLE_CLAUDEAI_MCP_SERVERS:-unset}" "$settings" "$deny" >>"$FAKE_DIR/profiles.log"
[ "$role" != VALIDATOR ] || printf '%s' "$prompt" >"$FAKE_DIR/validator-prompt.txt"
[ "$role" != VALIDATOR ] || { pwd -P; git rev-parse --show-toplevel HEAD; git remote get-url origin; cat .claude/settings.local.json; ls node_modules; } >"$FAKE_DIR/validator-cwd" 2>/dev/null
[ "$role" != PHASEA_ONLY ] || printf '%s' "$prompt" >"$FAKE_DIR/phasea-prompt.txt"
if [ "$role" = VERIFY ]; then
  settings='' prev=''
  for arg in "${flags[@]}"; do
    [ "$prev" != --settings ] || settings="$arg"
    prev="$arg"
  done
  printf '%s\n' "$settings" >"$FAKE_DIR/verify-settings.json"
  if [[ "$prompt" = /acme:verify-fixes* ]] && [ "${FAKE_REQUIRE_USER_PLUGIN:-}" = 1 ]; then
    jq -e '.enabledPlugins["acme@acme"] == true' <<<"$settings" >/dev/null || exit 1
  fi
fi
[ "$role" != VERIFY ] || printf '%s' "$prompt" >"$FAKE_DIR/verify-prompt.txt"
[ "$role" != DELTA ] || printf '%s' "$prompt" >"$FAKE_DIR/delta-prompt.txt"
[ "$role" != THERMO ] || printf '%s' "$prompt" >"$FAKE_DIR/thermo-prompt.txt"
[ "$role" != AUTOREVIEW ] || printf '%s' "$prompt" >"$FAKE_DIR/autoreview-prompt.txt"
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
  printf '\n<!-- claudine:v1 {"kind":"run","run":"7-1-me","sha":"{{SHA}}","findings":%s,"floor":"major","suppressed":0,"security":"%s","lenses":["done"]} -->' \
    "$1" "${2:-none}"
}


RC=0

direct_council() {
  : >"$FAKE_LOG"
  : >"$FAKE_DIR/posts.log"
  rm -f "$FAKE_DIR/validator-prompt.txt" "$FAKE_DIR/phasea-prompt.txt" "$FAKE_DIR/phase-a-ran" "$FAKE_DIR/user-calls" "$FAKE_DIR/review-reads"
  RC=0
  (cd "$CLONE" && PATH="$HOME/.local/bin:$PATH" /bin/bash "$SCRIPTS/pr-council-review/run.sh" 7 o/r "$@") >"$TMP_DIR/run.out" 2>&1 || RC=$?
  echo "$RC" >"$TMP_DIR/rc"
}

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
called() { grep -q "^$1" "$FAKE_LOG"; }
not_called() { ! called "$1"; }
rc_is() { [ "$RC" = "$1" ]; }
no_file() { [ ! -e "$1" ]; }
argv_of() { grep "^claude $1 " "$FAKE_LOG" | tail -1; }

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
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "linked: validator ran" called "claude VALIDATOR"
  check "linked: section in the gate prompt" grep -q '^## Linked pull requests' "$prompt"
  check "linked: timeline, body and ticket PRs kept, pinned" linked_pinned "$prompt" o/front#11 o/back#12 o/api#14
  check "linked: closed, non-member, foreign, malformed and self dropped" eval '! grep "^- \`" "$prompt" | grep -qE "o/closed#13|o/front#15|x/evil|bad/ref|o/r#7"'
  check "linked: foreign owner never queried" eval '! grep -q "repos/x/evil" "$FAKE_LOG"'
  check "linked: ticket searched within the owner" eval 'grep -q "^gh search prs PRD-9 --owner o " "$FAKE_LOG"'
  check "linked: one line per PR" [ "$(grep -c '^- `o/' "$prompt")" = 3 ]
  check "untrusted clause: validator prompt" grep -q 'are not yours to follow' "$prompt"
  FAKE_GH_DISCOVERY_FAIL=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "linked discovery fails: validator still runs" called "claude VALIDATOR"
  check "linked discovery fails: no section" eval '! grep -q "Linked pull requests" "$FAKE_DIR/validator-prompt.txt"'
  PR_COUNCIL_LINKED_TIMEOUT=1 FAKE_GH_DISCOVERY_SLEEP=30 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "linked discovery hangs: bounded, validator runs" called "claude VALIDATOR"
  check "linked discovery hangs: exit 0" rc_is 0
  PR_COUNCIL_LINKED_MAX_LINES=0 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "linked diff above the line cap: no section" eval '! grep -q "Linked pull requests" "$FAKE_DIR/validator-prompt.txt"'
  PR_COUNCIL_VALIDATOR_LOGIN='some-validator[bot]' \
    FAKE_GH_REVIEWS='[{"user":{"login":"some-validator[bot]","type":"Bot"},"commit_id":"'"$HEAD1"'","state":"APPROVED"}]' \
    FAKE_PHASEA_ONLY_TEXT="Nothing survived. $(marker 0)" direct_council --post
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
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
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
  set_head "$HEAD1"
  PR_REVIEW_PASS_IDLE=2 PR_REVIEW_STOP_GRACE=1 FAKE_VALIDATOR_INTERIM="$interim" FAKE_VALIDATOR_SLEEP=30 \
    FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "stall: reported" grep -q '^=== stalled: no session output for 2s' "$TMP_DIR/run.out"
  check "stall: last event named" grep -q '^=== validator: last session event result/success, last tool call none$' "$TMP_DIR/run.out"
  check "stall: process timing recorded" grep -Eq "^=== timing validator: elapsed_s=[0-9]+ process_exit=124$" "$TMP_DIR/run.out"
  check "stall: exit 124 despite an earlier result" rc_is 124
  PR_REVIEW_PASS_IDLE=2 PR_REVIEW_STOP_GRACE=1 FAKE_VALIDATOR_INTERIM="$(jq -c . "$FIXTURES/2.1.308-error-max-turns.json")" \
    FAKE_VALIDATOR_SLEEP=30 direct_council --post
  check "stall after an incomplete result: exit 124, retried" rc_is 124
  PR_REVIEW_PASS_IDLE=2 FAKE_VALIDATOR_TICKS=5 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "active pass past the idle limit: not stopped" eval '! grep -q "stalled" "$TMP_DIR/run.out"'
  check "active pass past the idle limit: exit 0" rc_is 0
  check "idle 0: limit off" [ "$(idle_setting 0)" = 0 ]
  check "idle not an integer: default limit" [ "$(idle_setting x)" = 900 ]
  check "idle unset: default limit" [ "$(idle_setting '')" = 900 ]
  check "idle 0: a silent command runs to its end" idle_run 0 'sleep 2'
  check "idle 1: a silent command is stopped" eval '! idle_run 1 "sleep 4"'
  check "idle 1: writes 0.6 s apart are not a stall" idle_run 1 'for i in 1 2 3 4 5; do sleep 0.6; echo x >>"$IDLE_FILE"; done'
  FAKE_VALIDATOR_INTERIM="$interim" FAKE_VALIDATOR_ENVELOPE=error-max-turns direct_council --post
  check "success then error: the last result wins" grep -q 'subtype=error_max_turns' "$TMP_DIR/run.out"
  check "success then error: cli exits 4" rc_is 4
  FAKE_VALIDATOR_NORESULT=1 direct_council --post
  check "no result line: the pass fails" eval '! rc_is 0 && grep -q "could not parse the session output" "$TMP_DIR/run.out"'
}

case_council_hangup() {
  local pid repo
  set_head "$HEAD1"
  rm -f "$FAKE_DIR/validator-cwd"
  PR_REVIEW_STOP_GRACE=1 FAKE_VALIDATOR_SLEEP=37 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post &
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

case_codex_member() {
  set_head "$HEAD1"
  FAKE_CODEX_TEXT="codex finding a.txt:1" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "codex member: read-only sol xhigh" grep -q -- "^codex exec .*--sandbox read-only .*--model gpt-6.1-sol -c model_reasoning_effort=\"xhigh\"" "$FAKE_LOG"
  check "codex member: report reaches the validator" grep -q "cross-family member" "$FAKE_DIR/validator-prompt.txt"
  check "codex member: process timing recorded" grep -Eq "^=== timing codex: elapsed_s=[0-9]+ process_exit=0$" "$TMP_DIR/run.out"
  check "codex member: exit 0" rc_is 0
  FAKE_CODEX_RC=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "codex failure: validator still runs" called "claude VALIDATOR"
  check "codex failure: same-family" grep -q "Phase A was same-family" "$FAKE_DIR/validator-prompt.txt"
  check "codex failure: process timing recorded" grep -Eq "^=== timing codex: elapsed_s=[0-9]+ process_exit=1$" "$TMP_DIR/run.out"
  check "codex failure: council marked degraded" grep -q "^=== council degraded: a required phase A pass failed$" "$TMP_DIR/run.out"
  PR_COUNCIL_USE_CODEX=0 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "codex opt-out: not called" not_called codex
  check "codex opt-out: same-family" grep -q "Phase A was same-family" "$FAKE_DIR/validator-prompt.txt"
  check "codex opt-out: exit 0" rc_is 0
}

case_one_phase_a_pass_fails() {
  set_head "$HEAD1"
  FAKE_THERMO_RC=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "one phase A pass fails: validator still runs" called "claude VALIDATOR"
  check "one phase A pass fails: the gap reaches the validator" grep -q "thermo-nuclear pass failed" "$FAKE_DIR/validator-prompt.txt"
  FAKE_QUALITY_RC=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "code-review pass fails: validator still runs" called "claude VALIDATOR"
  check "code-review pass fails: the gap reaches the validator" grep -q "/code-review pass failed" "$FAKE_DIR/validator-prompt.txt"
  FAKE_QUALITY_RC=1 FAKE_THERMO_RC=1 FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "both Claude phase A passes fail: no validator" not_called "claude VALIDATOR"
  check "both Claude phase A passes fail: said so" grep -q "both Claude phase A passes failed" "$TMP_DIR/run.out"
}

case_validator_checkout_bare_flagged() {
  local seen="$FAKE_DIR/validator-cwd"
  mkdir -p "$CLONE/.claude"
  echo '{"local":1}' >"$CLONE/.claude/settings.local.json"
  git -C "$CLONE" config core.bare true
  rm -f "$seen"
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "bare-flagged clone: validator ran" called "claude VALIDATOR"
  check "bare-flagged clone: no work-tree error" eval '! grep -q "must be run in a work tree" "$TMP_DIR/run.out"'
  check "bare-flagged clone: at the clone's head" [ "$(sed -n 3p "$seen")" = "$(git -C "$CLONE" rev-parse HEAD)" ]
  check "bare-flagged clone: origin carried" [ "$(sed -n 4p "$seen")" = "$(git -C "$CLONE" remote get-url origin)" ]
  check "bare-flagged clone: local settings carried" [ "$(sed -n 5p "$seen")" = '{"local":1}' ]
  mkdir -p "$CLONE/nested"
  check "bare-flagged clone: root discovery from nested cwd" [ "$(cd "$CLONE/nested" && . "$SCRIPTS/pr-council-review/lib.sh" && repo_root)" = "$CLONE" ]
  check "bare-flagged clone: flag unchanged" [ "$(git -C "$CLONE" config core.bare)" = true ]
  git -C "$CLONE" config core.bare false
  rm -rf "$CLONE/.claude" "$CLONE/nested"
  git clone -q --bare "$CLONE" "$TMP_DIR/genuine.git"
  check "true bare: root discovery retains repository path" [ "$(cd "$TMP_DIR/genuine.git" && . "$SCRIPTS/pr-council-review/lib.sh" && repo_root)" = "$TMP_DIR/genuine.git" ]
  check "true bare: validator checkout resolves head and origin" eval '(
    cd "$TMP_DIR/genuine.git"
    . "$SCRIPTS/pr-council-review/lib.sh"
    tree="$TMP_DIR/genuine-validator"
    validator_checkout "$tree" || exit 1
    test "$(git -C "$tree" rev-parse HEAD)" = "$(git rev-parse HEAD)" &&
      test "$(git -C "$tree" remote get-url origin)" = "$CLONE"
    rc=$?
    rm -rf "$tree"
    exit "$rc"
  )'
  rm -rf "$TMP_DIR/genuine.git"
}

case_reuse_fingerprint() {
  local repo="$TMP_DIR/fp" head sha_root sha_sub sha_archive sha_old sha_other
  git init -q -b main "$repo"
  mkdir -p "$repo/docs/plan" "$repo/sub"
  echo old >"$repo/docs/plan/old.md"; echo a >"$repo/a.txt"; echo s >"$repo/sub/s.txt"
  git -C "$repo" add -A && git -C "$repo" commit -q -m base
  git -C "$repo" checkout -q -b feature
  echo b >>"$repo/a.txt" && git -C "$repo" commit -q -am change
  head="$(git -C "$repo" rev-parse HEAD)"
  sha_root="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  sha_sub="$(cd "$repo/sub" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: same from a subdirectory" eval '[ -n "$sha_root" ] && [ "$sha_root" = "$sha_sub" ]'
  check "fingerprint: not the empty diff" [ "$sha_root" != "$(printf '' | shasum -a 256 | cut -d' ' -f1)" ]
  sha_other="$(cd "$repo" && GIT_CONFIG_COUNT=4 GIT_CONFIG_KEY_0=diff.noprefix GIT_CONFIG_VALUE_0=true \
    GIT_CONFIG_KEY_1=core.abbrev GIT_CONFIG_VALUE_1=12 GIT_CONFIG_KEY_2=diff.renames GIT_CONFIG_VALUE_2=copies \
    GIT_CONFIG_KEY_3=color.diff GIT_CONFIG_VALUE_3=always /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: diff settings do not change it" [ "$sha_root" = "$sha_other" ]
  echo archive >"$repo/docs/plan/new.md" && git -C "$repo" add docs/plan && git -C "$repo" commit -q -m archive
  sha_archive="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: an added plan archive is left out" [ "$sha_root" = "$sha_archive" ]
  echo edited >>"$repo/docs/plan/old.md" && git -C "$repo" commit -q -am "edit old archive"
  sha_old="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: an edited existing archive counts" [ "$sha_root" != "$sha_old" ]
  git -C "$repo" checkout -q "$head"
  echo z >>"$repo/sub/s.txt" && git -C "$repo" commit -q -am "outside the caller dir"
  sha_sub="$(cd "$repo/sub" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  sha_other="$(cd "$repo/docs" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: a change outside the caller's dir counts" eval '[ "$sha_root" != "$sha_other" ] && [ "$sha_sub" = "$sha_other" ]'
  printf 'sub/*\n' >"$TMP_DIR/fp-order"
  sha_other="$(cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.orderFile GIT_CONFIG_VALUE_0="$TMP_DIR/fp-order" \
    /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: diff.orderFile does not reorder it" [ "$sha_sub" = "$sha_other" ]
  check "fingerprint: a git failure prints nothing and fails" eval '! sha_other="$(cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.orderFile GIT_CONFIG_VALUE_0="$TMP_DIR/no-such-order" /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  git -C "$repo" checkout -q main
  check "fingerprint: an empty diff prints nothing and fails" eval '! sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  git -C "$repo" checkout -q "$head"
  echo archive >"$repo/docs/plan/été.md" && git -C "$repo" add docs/plan && git -C "$repo" commit -q -m "non-ascii archive"
  sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: a non-ascii plan archive is left out" [ "$sha_root" = "$sha_other" ]
  git -C "$repo" checkout -q "$head"
  ln -s a.txt "$repo/docs/plan/link.md" && git -C "$repo" add docs/plan && git -C "$repo" commit -q -m "symlink in plan"
  sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: a non-file addition under docs/plan counts" [ "$sha_root" != "$sha_other" ]
  git -C "$repo" checkout -q "$head"
  git -C "$repo" update-index --add --cacheinfo "160000,$head,mod" && git -C "$repo" commit -q -m gitlink
  mkdir -p "$repo/mod"
  sha_other="$(cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.ignoreSubmodules GIT_CONFIG_VALUE_0=all \
    /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: a gitlink change counts under diff.ignoreSubmodules=all" [ "$sha_root" != "$sha_other" ]
  git -C "$repo" checkout -q "$head"
  chmod +x "$repo/a.txt" && git -C "$repo" commit -q -am "mode only"
  sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: a mode-only change counts" [ "$sha_root" != "$sha_other" ]
  git -C "$repo" checkout -q "$head"
  echo x >"$repo/docs/plan/run.sh" && chmod +x "$repo/docs/plan/run.sh" && git -C "$repo" add docs/plan && git -C "$repo" commit -q -m "executable in plan"
  sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: an executable addition under docs/plan counts" [ "$sha_root" != "$sha_other" ]
  git -C "$repo" checkout -q "$head"
  git -C "$repo" rm -q docs/plan/old.md && git -C "$repo" commit -q -m "drop old archive"
  sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: a deletion under docs/plan counts" [ "$sha_root" != "$sha_other" ]
  git -C "$repo" checkout -q "$head"
  echo uncommitted >>"$repo/a.txt"
  check "fingerprint: an uncommitted tracked change prints nothing and fails" eval '! sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  git -C "$repo" checkout -q -- a.txt
  echo new >"$repo/untracked.txt"
  check "fingerprint: an untracked file prints nothing and fails" eval '! sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  check "fingerprint: an untracked file is refused under status.showUntrackedFiles=no" eval '! sha_other="$(cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=status.showUntrackedFiles GIT_CONFIG_VALUE_0=no /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  rm "$repo/untracked.txt"
  check "fingerprint: a failing git status prints nothing and fails" eval '! sha_other="$(cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=status.relativePaths GIT_CONFIG_VALUE_0=invalid /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  echo b2 >>"$repo/a.txt" && git -C "$repo" add a.txt
  check "fingerprint: a staged-only change prints nothing and fails" eval '! sha_other="$(cd "$repo" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main 2>/dev/null)" && [ -z "$sha_other" ]'
  git -C "$repo" reset -q --hard "$head"
  printf 'PLAN.md\n' >"$repo/.git/info/exclude" && echo plan >"$repo/PLAN.md"
  sha_other="$(cd "$repo/sub" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  check "fingerprint: an ignored file does not refuse, from a subdirectory" [ "$sha_root" = "$sha_other" ]
  rm "$repo/PLAN.md"
}

case_record_review() {
  local repo="$TMP_DIR/record" script="$SCRIPTS/pr-council-review/run.sh" sha out rc key flag
  : >"$TMP_DIR/run.out"
  git init -q -b main "$repo"
  echo base >"$repo/a"; git -C "$repo" add a; git -C "$repo" commit -q -m base
  git -C "$repo" checkout -q -b feature
  echo change >>"$repo/a"; git -C "$repo" commit -q -am change
  printf 'complete review\nwith literal $() text\n\n' >"$TMP_DIR/review report.md"
  sha="$(cd "$repo" && /bin/bash "$script" --reuse-sha main)"
  { printf 'patch-sha256: %s\n' "$sha"; cat "$TMP_DIR/review report.md"; } >"$TMP_DIR/expected-record"
  (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || :
  check "record: exact report bytes, including final newlines" cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"
  for out in "$TMP_DIR/missing-review" "$repo" "$TMP_DIR/empty-review"; do
    : >"$TMP_DIR/empty-review"
    rc=0
    (cd "$repo" && /bin/bash "$script" --record-review main "$out" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
    check "record: missing, directory or empty input refuses" [ "$rc" != 0 ]
    check "record: invalid input emits no partial record" cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"
  done
  for flag in assume-unchanged skip-worktree; do
    git -C "$repo" update-index "--$flag" a
    echo hidden >>"$repo/a"
    for out in --reuse-sha --record-review; do
      rc=0
      if [ "$out" = --reuse-sha ]; then
        (cd "$repo" && /bin/bash "$script" --reuse-sha main) >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
      else
        (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
      fi
      check "record: $out refuses $flag" [ "$rc" != 0 ]
      check "record: masked state has no stdout" test ! -s "$TMP_DIR/record.stdout"
      check "record: masked state preserves prior record" cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"
    done
    git -C "$repo" update-index "--no-$flag" a
    git -C "$repo" checkout -q -- a
  done
  for key in GIT_INDEX_FILE GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES; do
    for out in --reuse-sha --record-review; do
      rc=0
      if [ "$out" = --reuse-sha ]; then
        (cd "$repo" && env "$key=" /bin/bash "$script" --reuse-sha main) >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
      else
        (cd "$repo" && env "$key=" /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
      fi
      check "record: $out refuses set-empty $key" [ "$rc" != 0 ]
      check "record: override refusal has no stdout" test ! -s "$TMP_DIR/record.stdout"
      check "record: override preserves prior record" cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"
    done
  done
  printf '#!/bin/sh\ntouch "%s"\n' "$TMP_DIR/fsmonitor-ran" >"$TMP_DIR/fsmonitor"
  chmod +x "$TMP_DIR/fsmonitor"
  rc=0
  (cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0="$TMP_DIR/fsmonitor" /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: fsmonitor config is neutralized" test ! -e "$TMP_DIR/fsmonitor-ran"
  check "record: ordinary clean record still succeeds" eval '[ "$rc" = 0 ] && cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"'
  check "record: success emits no stdout" test ! -s "$TMP_DIR/record.stdout"
  check "record: private destination mode" python3 -c 'import os,stat,sys;sys.exit(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)!=0o600)' "$TMP_DIR/record.out"
  mkdir "$TMP_DIR/output-dir" "$TMP_DIR/clean-tree"
  cp "$repo/a" "$TMP_DIR/clean-tree/a"
  rc=0
  (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/output-dir") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: directory destination refuses without children" eval '[ "$rc" != 0 ] && [ -z "$(ls -A "$TMP_DIR/output-dir")" ]'
  ln -s "$TMP_DIR/output-dir" "$TMP_DIR/output-link"
  rc=0
  (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/output-link") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: symlink to directory also refuses" eval '[ "$rc" != 0 ] && [ -z "$(ls -A "$TMP_DIR/output-dir")" ]'
  echo dirty >>"$repo/a"
  for key in local env; do
    [ "$key" != local ] || git -C "$repo" config core.worktree "$TMP_DIR/clean-tree"
    for out in --reuse-sha --record-review; do
      rc=0
      if [ "$key" = env ]; then
        if [ "$out" = --reuse-sha ]; then
          (cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.worktree GIT_CONFIG_VALUE_0="$TMP_DIR/clean-tree" /bin/bash "$script" --reuse-sha main) >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
        else
          (cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.worktree GIT_CONFIG_VALUE_0="$TMP_DIR/clean-tree" /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
        fi
      else
        if [ "$out" = --reuse-sha ]; then
          (cd "$repo" && /bin/bash "$script" --reuse-sha main) >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
        else
          (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
        fi
      fi
      check "record: $out refuses $key core.worktree" eval '[ "$rc" != 0 ] && [ ! -s "$TMP_DIR/record.stdout" ]'
      check "record: config guard reached" grep -qF core.worktree "$TMP_DIR/record.err"
      check "record: config refusal preserves destination" cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"
    done
    [ "$key" != local ] || git config --file "$repo/.git/config" --unset core.worktree
  done
  git -C "$repo" checkout -q -- a
  git -C "$repo" config core.worktree ""
  rc=0
  (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: set-empty core.worktree refuses" eval '[ "$rc" != 0 ] && cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"'
  git config --file "$repo/.git/config" --unset core.worktree
  printf '[broken\n' >"$TMP_DIR/broken-gitconfig"
  rc=0
  (cd "$repo" && GIT_CONFIG_GLOBAL="$TMP_DIR/broken-gitconfig" /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: config-read error preserves destination" eval '[ "$rc" != 0 ] && [ ! -s "$TMP_DIR/record.stdout" ] && cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"'
  printf 'replace this old record\n' >"$TMP_DIR/record.out"
  rc=0
  (cd "$repo" && GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.noprefix GIT_CONFIG_VALUE_0=true /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") || rc=$?
  check "record: harmless diff config writes new exact bytes" eval '[ "$rc" = 0 ] && cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"'
  mkdir "$TMP_DIR/race-bin"
  printf '#!/bin/bash\n"$RACE_REAL_CAT" "$@" || exit\nif [ "$#" = 1 ]; then rm -f "$RACE_OUTPUT"; mkdir "$RACE_OUTPUT"; fi\n' >"$TMP_DIR/race-bin/cat"
  chmod +x "$TMP_DIR/race-bin/cat"
  printf 'old record\n' >"$TMP_DIR/race.out"
  rc=0
  (cd "$repo" && PATH="$TMP_DIR/race-bin:$PATH" RACE_REAL_CAT=/bin/cat RACE_OUTPUT="$TMP_DIR/race.out" /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/race.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: concurrent directory refuses with no hidden artifact" eval '[ "$rc" != 0 ] && [ -d "$TMP_DIR/race.out" ] && [ -z "$(ls -A "$TMP_DIR/race.out")" ]'
  python3 - "$repo" "$script" "$TMP_DIR/large-review.md" "$TMP_DIR/record.out" <<'PY'
import pathlib,resource,subprocess,sys
report=pathlib.Path(sys.argv[3]);report.write_bytes(b"evidence\n"*4096)
limit=report.stat().st_size
result=subprocess.run(["/bin/bash",sys.argv[2],"--record-review","main",str(report),sys.argv[4]],cwd=sys.argv[1],stdout=subprocess.PIPE,stderr=subprocess.PIPE,preexec_fn=lambda:resource.setrlimit(resource.RLIMIT_FSIZE,(limit,limit)))
sys.exit(0 if result.returncode != 0 and result.stdout == b"" else 1)
PY
  check "record: I/O failure preserves prior valid record" cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"
  check "record: no output temporary remains" eval '[ -z "$(find "$TMP_DIR" -name ".pr-review-record.*" -print)" ]'
  echo dirty >>"$repo/a"
  rc=0
  (cd "$repo" && /bin/bash "$script" --record-review main "$TMP_DIR/review report.md" "$TMP_DIR/record.out") >"$TMP_DIR/record.stdout" 2>"$TMP_DIR/record.err" || rc=$?
  check "record: dirty report refuses without stdout" eval '[ "$rc" != 0 ] && cmp -s "$TMP_DIR/expected-record" "$TMP_DIR/record.out"'
}

case_usage_head() {
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" direct_council --post
  check "usage: council binds usage and timing to head" eval 'grep -qF "$(printf "\to/r#7@%s\tcode-review:" "$HEAD1")" "$PR_REVIEW_USAGE_LOG" && grep -qF "$(printf "\to/r#7@%s\ttiming code-review:" "$HEAD1")" "$PR_REVIEW_USAGE_LOG"'
  set_head "$HEAD1"
  autoreview
  check "usage: autoreview has its actual head" grep -qF "$(printf '\to/r#7@%s\tautoreview:' "$HEAD1")" "$PR_REVIEW_USAGE_LOG"
}

case_reuse_review() {
  local sha archived
  git -C "$TMP_DIR/seed" checkout -q "$HEAD1"
  sha="$(cd "$TMP_DIR/seed" && /bin/bash "$SCRIPTS/pr-council-review/run.sh" --reuse-sha main)"
  git -C "$TMP_DIR/seed" checkout -q feature
  printf 'patch-sha256: %s\nrecorded final review: reused finding a.txt:1\n' "$sha" >"$TMP_DIR/reuse-ok.md"
  printf 'patch-sha256: %064d\nrecorded final review on another patch\n' 0 >"$TMP_DIR/reuse-stale.md"
  set_head "$HEAD1"
  PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/reuse-ok.md" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "reuse, same patch: phase A skipped" not_called "claude QUALITY"
  check "reuse, same patch: no thermo or codex pass" eval '! called "claude THERMO" && not_called codex'
  check "reuse, same patch: validator still runs" called "claude VALIDATOR"
  check "reuse, same patch: recorded review reaches the validator" grep -q "reused a recorded review" "$FAKE_DIR/validator-prompt.txt"
  check "reuse, same patch: exit 0" rc_is 0
  PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/reuse-stale.md" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "reuse, other patch: refused" grep -q "reuse refused: patch sha" "$TMP_DIR/run.out"
  check "reuse, other patch: full phase A" called "claude QUALITY"
  check "reuse, other patch: validator runs" called "claude VALIDATOR"
  PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/no-such-review.md" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "reuse, missing file: refused" grep -q "reuse refused: " "$TMP_DIR/run.out"
  check "reuse, missing file: full phase A" called "claude QUALITY"
  { printf 'context line\n'; cat "$TMP_DIR/reuse-ok.md"; } >"$TMP_DIR/reuse-late.md"
  PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/reuse-late.md" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "reuse, hash not on line 1: refused" grep -q "reuse refused: " "$TMP_DIR/run.out"
  # The plan archive commit lands after the final review; it must not void the reuse.
  git -C "$TMP_DIR/seed" checkout -q "$HEAD1"
  mkdir -p "$TMP_DIR/seed/docs/plan"
  echo archive >"$TMP_DIR/seed/docs/plan/20260101-x.md"
  git -C "$TMP_DIR/seed" add docs/plan
  git -C "$TMP_DIR/seed" commit -q -m archive
  archived="$(git -C "$TMP_DIR/seed" rev-parse HEAD)"
  git -C "$TMP_DIR/seed" checkout -q feature
  set_head "$archived"
  PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/reuse-ok.md" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "reuse, plan archive added: phase A skipped" not_called "claude QUALITY"
  check "reuse, plan archive added: validator runs" called "claude VALIDATOR"
  # A head that adds only a plan archive has no fingerprint: refuse on that, not on a hash mismatch.
  git -C "$TMP_DIR/seed" checkout -q -b archive-only main
  mkdir -p "$TMP_DIR/seed/docs/plan"
  echo archive >"$TMP_DIR/seed/docs/plan/20260101-y.md"
  git -C "$TMP_DIR/seed" add docs/plan
  git -C "$TMP_DIR/seed" commit -q -m archive
  archived="$(git -C "$TMP_DIR/seed" rev-parse HEAD)"
  git -C "$TMP_DIR/seed" checkout -q feature
  set_head "$archived"
  PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/reuse-ok.md" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "reuse, no fingerprint: refused on the fingerprint" grep -q "reuse refused: cannot fingerprint" "$TMP_DIR/run.out"
  check "reuse, no fingerprint: full phase A" called "claude QUALITY"
  # The validator already reviewed this head: phase B would only verify the
  # reused findings, so the reuse is refused and phase A runs.
  set_head "$HEAD1"
  PR_COUNCIL_VALIDATOR_LOGIN=some-validator[bot] FAKE_GH_REVIEWS='[{"user":{"login":"some-validator[bot]","type":"Bot"},"commit_id":"'"$HEAD1"'","state":"COMMENTED"}]' \
    PR_COUNCIL_REUSE_REVIEW="$TMP_DIR/reuse-ok.md" FAKE_PHASEA_ONLY_TEXT="Nothing survived. $(marker 0)" direct_council --post
  check "reuse, validator already on head: refused" grep -q "reuse refused: the validator already reviewed" "$TMP_DIR/run.out"
  check "reuse, validator already on head: phase A runs" called "claude QUALITY"
}

case_phase_a_denial_vetoes() {
  set_head "$HEAD1"
  FAKE_QUALITY_ENVELOPE=denied FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "phase A denial: fakes answered" called "claude QUALITY"
  check "phase A denial: validator not run" not_called "claude VALIDATOR"
  check "phase A denial: veto exit" rc_is 3
}

case_timing_returns() {
  local sample log rc expected process_rc envelope missing mode expected_text
  for sample in success missing passthrough denied incomplete timeout; do
    expected=0 process_rc=0 envelope=success missing='' mode=normal expected_text=timing-sentinel
    case "$sample" in
      missing) expected=1 missing=1 expected_text='' ;;
      passthrough) expected=7 process_rc=7 ;;
      denied) expected=3 envelope=denied ;;
      incomplete) expected=4 envelope=error-max-turns process_rc=1 ;;
      timeout) expected=124 process_rc=124 mode=timeout expected_text='' ;;
    esac
    for log in "$TMP_DIR/timing.log" /dev/null/timing.log; do
      rc=0
      PR_REVIEW_USAGE_LOG="$log" FAKE_QUALITY_ENVELOPE="$envelope" FAKE_QUALITY_NORESULT="$missing" \
        FAKE_QUALITY_PATCH='.result = "timing-sentinel"' FAKE_QUALITY_TEXT=timing-sentinel FAKE_QUALITY_RC="$process_rc" /bin/bash -c '
          . "$1"
          if [ "$3" = timeout ]; then run_with_timeout() { return 124; }; fi
          claude_pass code-review "$2" read-only "/code-review high" "${ISOLATED_SETTINGS[@]}"
        ' _ "$SCRIPTS/pr-council-review/lib.sh" "$TMP_DIR/timed.json" "$mode" >"$TMP_DIR/timed.out" 2>"$TMP_DIR/timed.err" || rc=$?
      check "timing $sample ($log): semantic exit unchanged" [ "$rc" = "$expected" ]
      if [ -n "$expected_text" ]; then printf '%s\n' "$expected_text"; fi >"$TMP_DIR/timed.expected"
      check "timing $sample ($log): report bytes unchanged" cmp -s "$TMP_DIR/timed.expected" "$TMP_DIR/timed.out"
      check "timing $sample ($log): process exit recorded" grep -Eq "^=== timing code-review: elapsed_s=[0-9]+ process_exit=$process_rc$" "$TMP_DIR/timed.err"
    done
  done
  /bin/bash -c '. "$1"; SECONDS=20; record_timing clock-test 13 7' _ "$SCRIPTS/pr-council-review/lib.sh" 2>"$TMP_DIR/clock.err"
  check "timing: elapsed uses caller clock" grep -Eq '^=== timing clock-test: elapsed_s=(7|8) process_exit=7$' "$TMP_DIR/clock.err"
  check "timing: failed log write is safe under errexit" env PR_REVIEW_USAGE_LOG=/dev/null/timing.log /bin/bash -ec '. "$1"; record_timing clock-test "$SECONDS" 0' _ "$SCRIPTS/pr-council-review/lib.sh"
  check "timing: elapsed persists in usage log" grep -Eq 'timing clock-test: elapsed_s=(7|8) process_exit=7$' "$PR_REVIEW_USAGE_LOG"
}

case_codex_timing_returns() {
  local sample log rc expected process_rc mode
  for sample in success missing failure timeout; do
    expected=0 process_rc='' mode=normal
    case "$sample" in
      missing) expected=1 process_rc=0 ;;
      failure) expected=1 process_rc=1 ;;
      timeout) expected=124 process_rc=124 mode=timeout ;;
    esac
    for log in "$TMP_DIR/timing.log" /dev/null/timing.log; do
      rm -f "$TMP_DIR/timed-codex.md"
      rc=0
      PR_REVIEW_USAGE_LOG="$log" FAKE_CODEX_RC="$process_rc" FAKE_CODEX_TEXT=timing-sentinel /bin/bash -c '
        . "$1"
        if [ "$4" = timeout ]; then run_with_timeout() { return 124; }; fi
        codex_pass "$2" "$3" gpt-6.1-sol xhigh "test"
      ' _ "$SCRIPTS/pr-council-review/lib.sh" "$CLONE" "$TMP_DIR/timed-codex.md" "$mode" >"$TMP_DIR/timed.out" 2>"$TMP_DIR/timed.err" || rc=$?
      check "codex timing $sample ($log): semantic exit" [ "$rc" = "$expected" ]
      check "codex timing $sample ($log): stdout empty" [ ! -s "$TMP_DIR/timed.out" ]
      check "codex timing $sample ($log): process exit" grep -Eq "^=== timing codex: elapsed_s=[0-9]+ process_exit=${process_rc:-0}$" "$TMP_DIR/timed.err"
    done
  done
}

case_validator_profile() {
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" direct_council --post
  check "validator: fakes answered" called "claude VALIDATOR"
  check "validator: auto profile" eval 'argv_of VALIDATOR | grep -q -- "--permission-mode auto --permission-prompts none "'
  check "validator: only the review POST is pre-allowed" eval 'argv_of VALIDATOR | grep -qF -- "--allowedTools Bash(gh api repos/o/r/pulls/7/reviews:*) "'
  check "validator: no bypass" eval '! argv_of VALIDATOR | grep -q -- --dangerously-skip-permissions'
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council
  check "validator: a dry-run validator answered" called "claude VALIDATOR"
  check "validator: a dry-run gets no review grant" eval '! argv_of VALIDATOR | grep -qF -- "--allowedTools"'
  FAKE_VALIDATOR_ENVELOPE=denied FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "validator: a denial vetoes" rc_is 3
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
  check "autoreview: timing recorded outside result" eval 'grep -Eq "^=== timing autoreview: elapsed_s=[0-9]+ process_exit=0$" "$TMP_DIR/run.out" && ! find "$TMPDIR" -name result.md -exec grep -l "=== timing" {} + | grep -q .'
  check "autoreview without DONE: exits non-zero" [ "$RC" != 0 ]
  check "autoreview without DONE: notifies" called "notify "
}

case_autoreview_reads_the_last_reviewed_head() {
  set_head "$HEAD1"
  local heads="$HOME/.claude/state/pr-autoreview-heads"
  rm -f "$heads"
  autoreview
  check "first autoreview: no prior head" grep -qF 'the same base: `none`' "$FAKE_DIR/autoreview-prompt.txt"
  printf 'o/r#7\t%s\tmain\no/r#70\t%s\tmain\no/rr#7\t%s\tmain\n' "$(printf '%040d' 1)" "$HEAD2" "$HEAD2" >"$heads"
  autoreview
  check "later autoreview: the last head of this PR only" grep -qF "the same base: \`$(printf '%040d' 1)\`" "$FAKE_DIR/autoreview-prompt.txt"
  printf 'o/r#7\t%s\tfeature\n' "$HEAD2" >>"$heads"
  autoreview
  check "later autoreview: a new base reviews the full diff" grep -qF 'the same base: `none`' "$FAKE_DIR/autoreview-prompt.txt"
  rm -f "$heads"
}

case_housekeeping() {
  local repo="$TMP_DIR/neutralize"
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
}

case_phase_a_only() {
  local review label reviews page2
  review() { printf '{"user":{"login":"%s","type":"%s"},"commit_id":"%s","state":"%s"}' "$1" "$2" "$3" "$4"; }
  export PR_COUNCIL_VALIDATOR_LOGIN=some-validator[bot]
  set_head "$HEAD1"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing survived. $(marker 0)" direct_council --post
  check "phase A only: validator not run" not_called "claude VALIDATOR"
  check "phase A only: verify pass runs on opus high" eval 'grep "^claude PHASEA_ONLY" "$FAKE_LOG" | grep -q -- "--model opus --effort high"'
  check "phase A only: phase A on opus high" eval 'grep "^claude QUALITY" "$FAKE_LOG" | grep -q -- "--model opus --effort high"'
  check "phase A only: exit 0" rc_is 0
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing new. $(marker 0)" direct_council --post
  check "validator commented: exit 0" rc_is 0
  check "validator commented: emits validator open marker" grep -q '"validator":"open"' "$TMP_DIR/run.out"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED),$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --post
  check "validator commented then approved: exit 0" rc_is 0
  check "validator commented then approved: no validator open marker" eval '! grep -q "\"validator\":\"open\"" "$TMP_DIR/run.out"'
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_AFTER="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing new. $(marker 0)" direct_council --post
  check "validator commented during pass: exit 0" rc_is 0
  check "validator commented during pass: emits validator open marker" grep -q '"validator":"open"' "$TMP_DIR/run.out"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_AFTER="[$(review some-validator[bot] Bot "$HEAD1" DISMISSED)]" \
    FAKE_PHASEA_ONLY_TEXT="Nothing new. $(marker 0)" direct_council --post
  check "validator dismissed during pass: exit 0" rc_is 0
  check "validator dismissed during pass: emits validator open marker" grep -q '"validator":"open"' "$TMP_DIR/run.out"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_AFTER="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review me User "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Posted. $(marker 1)" direct_council --phase-a-only --post
  check "phase A only --post with new review: exit 0" rc_is 0
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_FAIL_AT=2 \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --phase-a-only --post
  check "phase A only OWN_BEFORE read failure: exits 1" rc_is 1
  check "phase A only OWN_BEFORE read failure: no verify pass" not_called "claude PHASEA_ONLY"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review me User "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Submission failed. $(marker 1)" direct_council --post
  check "only an older review of ours: retryable failure" rc_is 1
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_GH_REVIEWS_MID="[$(review some-validator[bot] Bot "$HEAD1" APPROVED),$(review me User "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="Submission failed. $(marker 1)" direct_council --post
  check "review of ours posted during phase A: retryable failure" rc_is 1
  FAKE_GH_USER_FAIL_FROM=1 FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --post
  check "unreadable gh login: retryable failure" rc_is 1
  check "unreadable gh login: no verify pass" not_called "claude PHASEA_ONLY"
  check "unreadable gh login: reported by the council" eval 'grep -q "cannot read the gh login" "$TMP_DIR/run.out"'
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" APPROVED)]" \
    FAKE_PHASEA_ONLY_TEXT="Submission failed. $(marker 1)" direct_council --post
  check "findings kept but not posted: retryable failure" rc_is 1
  for label in "old head" "other bot" "similar bot" "dismissed" "pending"; do
    case "$label" in
      "old head") reviews="[$(review some-validator[bot] Bot "$HEAD2" COMMENTED)]" ;;
      "other bot") reviews="[$(review other[bot] Bot "$HEAD1" APPROVED)]" ;;
      "similar bot") reviews="[$(review openapi-validator[bot] Bot "$HEAD1" APPROVED)]" ;;
      dismissed) reviews="[$(review some-validator[bot] Bot "$HEAD1" DISMISSED)]" ;;
      pending) reviews="[$(review some-validator[bot] Bot "$HEAD1" PENDING)]" ;;
    esac
    FAKE_GH_REVIEWS="$reviews" FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
    check "$label: validator runs" called "claude VALIDATOR"
    check "$label: no phase A only" not_called "claude PHASEA_ONLY"
  done
  page2="[$(review some-validator[bot] Bot "$HEAD1" CHANGES_REQUESTED)]"
  FAKE_GH_REVIEWS="[$(review dev User "$HEAD1" COMMENTED)]" FAKE_GH_REVIEWS_PAGE2="$page2" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --post
  check "second page: phase A only" called "claude PHASEA_ONLY"
  PR_COUNCIL_PHASE_A_ONLY=0 FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "forced validator: validator runs" called "claude VALIDATOR"
  PR_COUNCIL_PHASE_A_ONLY=1 FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --post
  check "forced phase A only: no validator" not_called "claude VALIDATOR"
  check "forced phase A only: reviews still listed" called "gh api --paginate"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" FAKE_PHASEA_ONLY_TEXT="Nothing survived." \
    direct_council --post
  check "phase A only without marker: exits 0 cleanly without watcher" rc_is 0
  unset PR_COUNCIL_VALIDATOR_LOGIN
  mkdir -p "$HOME/.config/pr-council-review"
  echo some-validator[bot] >"$HOME/.config/pr-council-review/validator-login"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --post
  check "login from config file: phase A only" called "claude PHASEA_ONLY"
  rm -f "$HOME/.config/pr-council-review/validator-login"
  FAKE_GH_REVIEWS="[$(review some-validator[bot] Bot "$HEAD1" COMMENTED)]" \
    FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" direct_council --post
  check "no login: validator runs" called "claude VALIDATOR"
  PR_COUNCIL_PHASE_A_ONLY=1 direct_council --post
  check "no login, forced phase A only: usage error" rc_is 2
  check "no login, forced phase A only: no model call" not_called "claude"
}

case_usage_accounting() {
  local native="$FIXTURES/2.1.308-success.json" variant="$TMP_DIR/usage-variant.json" out
  out="$(. "$SCRIPTS/pr-council-review/lib.sh"; usage_line "$native" fixture 2.1.308)"
  check "usage scope: native cumulative includes possible restored spend" grep -qF 'scope=native-session-cumulative restored=possible' <<<"$out"
  check "usage scope: model totals are reported, not independently attributed" grep -qF 'modelUsage=reported-including-subagents' <<<"$out"
  check "usage scope: zero cost and error state retained" grep -qF 'cost=0 denials=0 is_error=false' <<<"$out"
  check "usage scope: pricing provenance" grep -qF 'basis=list' <<<"$out"
  jq '.modelUsage["claude-sonnet-5-5"] = {inputTokens:17,cacheCreationInputTokens:3,cacheReadInputTokens:5,outputTokens:11,thinkingTokens:7,costBasis:"managed"} | .total_cost_usd=2 | .result="PRIVATE_RESULT" | .session_id="PRIVATE_SESSION"' "$native" >"$variant"
  out="$(. "$SCRIPTS/pr-council-review/lib.sh"; usage_line "$variant" synthetic 2.1.308)"
  check "usage scope: all model entries, thinking not added twice" grep -qF 'claude-sonnet-5-5 in=17 cache_write=3 cache_read=5 out=11 basis=managed' <<<"$out"
  check "usage scope: original model retained" grep -qF 'claude-haiku-5-5 in=2' <<<"$out"
  check "usage scope: no session ID or result text" eval '! grep -qE "PRIVATE_RESULT|PRIVATE_SESSION" <<<"$out"'
  jq '.total_cost_usd=12 | .modelUsage["claude-haiku-5-5"].inputTokens=12000' "$native" >"$variant"
  out="$(. "$SCRIPTS/pr-council-review/lib.sh"; usage_line "$variant" synthetic-resumed 2.1.308)"
  check "usage scope: synthetic restored cumulative balance not relabeled a new-call delta" eval 'grep -qF "cost=12" <<<"$out" && grep -qF "scope=native-session-cumulative restored=possible" <<<"$out" && grep -qF "in=12000" <<<"$out"'
  jq 'del(.total_cost_usd,.modelUsage,.is_error)' "$native" >"$variant"
  out="$(. "$SCRIPTS/pr-council-review/lib.sh"; usage_line "$variant" synthetic 2.1.308)"
  check "usage scope: absent accounting stays unknown" grep -qF 'cost=? denials=0 is_error=? scope=native-session-cumulative restored=possible modelUsage=unknown' <<<"$out"
  jq '.is_error=true | .subtype="error_during_execution" | .total_cost_usd=0 | .modelUsage["claude-haiku-5-5"].inputTokens=null | .modelUsage["claude-haiku-5-5"].costBasis="unexpected"' "$native" >"$variant"
  out="$(. "$SCRIPTS/pr-council-review/lib.sh"; usage_line "$variant" synthetic 2.1.308)"
  check "usage scope: zero after error not marked successful" grep -qF 'subtype=error_during_execution cost=0 denials=0 is_error=true' <<<"$out"
  check "usage scope: missing model counter and pricing stay unknown" grep -qF 'in=? cache_write=5908 cache_read=10644 out=4 basis=unknown' <<<"$out"
  jq '.total_cost_usd="PRIVATE_COST" | .modelUsage["claude-haiku-5-5"].inputTokens="PRIVATE_COUNTER" | .modelUsage["claude-haiku-5-5"].outputTokens=-3 | .modelUsage["claude-haiku-5-5"].costBasis="PRIVATE_BASIS" | .result="PRIVATE_RESULT" | .session_id="PRIVATE_SESSION" | .is_error="true"' "$native" >"$variant"
  out="$(. "$SCRIPTS/pr-council-review/lib.sh"; usage_line "$variant" synthetic 2.1.308)"
  check "usage scope: invalid numeric fields are not echoed" eval 'grep -qF "cost=?" <<<"$out" && grep -qF "in=? cache_write=5908 cache_read=10644 out=?" <<<"$out" && ! grep -q PRIVATE <<<"$out"'
  check "usage scope: string is_error does not become a successful boolean" grep -qF 'is_error=?' <<<"$out"
}

case_token_rollout() {
  local script="$SCRIPTS/pr-council-review/run.sh" record before mode cache_dir
  set_head "$HEAD1"
  PR_COUNCIL_VALIDATOR_EFFORT=medium FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "effort: validator opt-in medium" grep -q 'claude VALIDATOR .*--effort medium' "$FAKE_LOG"
  check "effort: phase A stays high" grep -q 'claude QUALITY .*--effort high' "$FAKE_LOG"
  PR_COUNCIL_VALIDATOR_EFFORT=medium FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post --effort high
  check "effort: explicit council flag wins" grep -q 'claude VALIDATOR .*--effort high' "$FAKE_LOG"
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "effort: validator default high preserved" grep -q 'claude VALIDATOR .*--effort high' "$FAKE_LOG"
  PR_COUNCIL_VALIDATOR_EFFORT=medium PR_COUNCIL_VALIDATOR_LOGIN='validator[bot]' FAKE_GH_REVIEWS='[{"state":"APPROVED","commit_id":"'"$HEAD1"'","user":{"login":"validator[bot]"}}]' FAKE_PHASEA_ONLY_TEXT="$(marker 0)" direct_council --post
  check "effort: phase-a-only forces high" grep -q 'claude PHASEA_ONLY .*--effort high' "$FAKE_LOG"

  printf 'eligible round: two independent reviews and cross-family provenance\n' >"$TMP_DIR/eligible-report"
  # The recorder works on a clean checkout; PR review later uses this same checkout.
  git -C "$CLONE" checkout -q --detach "$HEAD1"
  record="$(cd "$CLONE" && /bin/bash "$script" --record-review origin/main "$TMP_DIR/eligible-report" --eligible-review)"
  check "auto reuse: recorder prints existing private path" test -f "$record"
  [ -f "$record" ] || return 0
  cache_dir="$(dirname "$record")"
  check "auto reuse: private directory and file" node -e '
    const fs = require("node:fs");
    const [dir, file] = process.argv.slice(1);
    process.exit((fs.statSync(dir).mode & 0o777) === 0o700 && (fs.statSync(file).mode & 0o777) === 0o600 ? 0 : 1);
  ' "$cache_dir" "$record"
  mkdir -p "$CLONE/empty-subdir"
  before="$(cd "$CLONE/empty-subdir" && /bin/bash "$script" --record-review origin/main "$TMP_DIR/eligible-report" --eligible-review)"
  check "auto reuse: recorder scoped to repo root" [ "$before" = "$record" ]
  cp "$record" "$TMP_DIR/eligible-original"
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "auto reuse: phase A skipped" not_called 'claude QUALITY'
  check "auto reuse: validator still runs" called 'claude VALIDATOR'
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post --no-reuse
  check "auto reuse: force refresh" called 'claude QUALITY'
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council
  check "auto reuse: no implicit dry-run reuse" called 'claude QUALITY'

  mkdir -p "$CLONE/docs/plan"
  echo archive >"$CLONE/docs/plan/token-rollout.md"
  git -C "$CLONE" add docs/plan
  git -C "$CLONE" commit -q -m archive
  before="$(git -C "$CLONE" rev-parse HEAD)"
  git -C "$CLONE" push -q origin HEAD:refs/pull/7/head
  set_head "$before"
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "auto reuse: archive commit preserves discovery" not_called 'claude QUALITY'

  for mode in expired future base repo patch unattested empty symlink; do
    cp "$TMP_DIR/eligible-original" "$record"
    if [ "$mode" = symlink ]; then
      rm "$record"; ln -s "$TMP_DIR/eligible-original" "$record"
    else
      node - "$record" "$mode" <<'NODE'
const fs = require('node:fs');
const [file, mode] = process.argv.slice(2);
const data = JSON.parse(fs.readFileSync(file, 'utf8'));
if (mode === 'expired') data.createdAt -= 3601;
if (mode === 'future') data.createdAt += 60;
if (mode === 'base') data.base = '0'.repeat(40);
if (mode === 'repo') data.repo += '/other';
if (mode === 'patch') data.patch = '0'.repeat(64);
if (mode === 'unattested') data.eligible = false;
if (mode === 'empty') data.report = '';
fs.writeFileSync(file, JSON.stringify(data));
NODE
    fi
    FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
    check "auto reuse: $mode refuses" called 'claude QUALITY'
    rm "$record"
  done
  cp "$TMP_DIR/eligible-original" "$record"; chmod 600 "$record"
  chmod 777 "$cache_dir"
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "auto reuse: unsafe directory refuses" called 'claude QUALITY'
  chmod 700 "$cache_dir"
  rm "$record"
  # Ordinary packaging stays explicit; no attestation is inferred from report text.
  (cd "$CLONE" && /bin/bash "$script" --record-review origin/main "$TMP_DIR/eligible-report" "$TMP_DIR/legacy-record")
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "auto reuse: legacy record never discovered" called 'claude QUALITY'
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post --reuse-review "$TMP_DIR/legacy-record"
  check "auto reuse: explicit legacy still works" not_called 'claude QUALITY'
  FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post --reuse-review "$TMP_DIR/legacy-record" --no-reuse
  check "auto reuse: no-reuse beats explicit file" called 'claude QUALITY'
}

case_unverified_envelopes() {
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 0)" FAKE_VALIDATOR_PATCH='.permission_denials = {}' direct_council --post
  check "denials as an object: fakes answered" called "claude VALIDATOR"
  check "denials as an object: vetoed" rc_is 3
  FAKE_VALIDATOR_PATCH=empty FAKE_VALIDATOR_RC=1 direct_council --post
  check "empty output: fakes answered" called "claude VALIDATOR"
  check "empty output: retryable failure, not incomplete" rc_is 1
  FAKE_VALIDATOR_PATCH=empty FAKE_VALIDATOR_RC=0 direct_council --post
  check "empty output with exit 0: retryable failure, not a veto" rc_is 1
}

case_pass_caps_and_diagnostics() {
  set_head "$HEAD1"
  FAKE_VALIDATOR_TEXT="Review posted. $(marker 2)" direct_council --post
  local role
  for role in QUALITY THERMO VALIDATOR; do
    check "caps: $role has the default turn cap" eval 'argv_of $role | grep -q -- "--max-turns 200 "'
    check "caps: $role has the default budget cap" eval 'argv_of $role | grep -q -- "--max-budget-usd 25 "'
    check "caps: $role runs with GIT_TERMINAL_PROMPT=0" eval 'argv_of $role | grep -q "GIT_TERMINAL_PROMPT=0 "'
  done
  check "diagnostics: usage line fields" grep -q 'claude_version=2.1.308 turns=1 subtype=success cost=0 denials=0' "$TMP_DIR/run.out"
  PR_REVIEW_MAX_TURNS=7 PR_REVIEW_MAX_BUDGET_USD=3 FAKE_VALIDATOR_RC=1 FAKE_VALIDATOR_STDERR="validator stderr tail" \
    FAKE_VALIDATOR_TEXT="$(marker 0)" direct_council --post
  check "caps: env overrides the turn cap" eval 'argv_of VALIDATOR | grep -q -- "--max-turns 7 --max-budget-usd 3 "'
  check "diagnostics: a non-zero exit logs the stderr tail" grep -q '^validator stderr tail$' "$TMP_DIR/run.out"
  check "diagnostics: a failed pass exits non-zero" eval '! rc_is 0'
}

if [ "${1:-}" = --token-rollout ]; then
case_token_rollout
elif [ "${1:-}" = --checkout ]; then
case_validator_checkout
case_validator_checkout_bare_flagged
elif [ "${1:-}" = --usage ]; then
case_usage_accounting
elif [ "${1:-}" = --efficiency ]; then
case_usage_accounting
case_reuse_fingerprint
case_record_review
case_usage_head
else
case_token_rollout
case_usage_accounting
case_codex_member
case_reuse_fingerprint
case_record_review
case_usage_head
case_reuse_review
case_one_phase_a_pass_fails
case_phase_a_denial_vetoes
case_timing_returns
case_codex_timing_returns
case_validator_profile
case_unverified_envelopes
case_pass_caps_and_diagnostics
case_autoreview_fails_loudly
case_autoreview_reads_the_last_reviewed_head
case_housekeeping
case_phase_a_only
case_linked_prs
case_validator_checkout
case_validator_checkout_bare_flagged
case_stalled_pass
case_council_hangup
fi

check_pass_profiles() {
  local log="$FAKE_DIR/profiles.log" role line want_mcp want_deny want_settings wrong=''
  [ $# -eq 0 ] || [ -s "$log" ] || return 0
  check "profiles: claude passes were logged" [ -s "$log" ]
  while read -r role line; do
    case "$role" in
      VALIDATOR|PHASEA_ONLY) want_mcp=false want_deny="|$LEAN_DENY" want_settings=0 ;;
      AUTOREVIEW) want_mcp=true want_deny="|Edit,Write,NotebookEdit,$LEAN_DENY" want_settings=0 ;;
      QUALITY|THERMO) want_mcp=false want_deny="|Edit,Write,NotebookEdit,$LEAN_DENY" want_settings=1 ;;
      *) want_mcp=unknown-role want_deny='' want_settings='' ;;
    esac
    [ "$line" = "FORCE_PROMPT_CACHING_5M=1 ENABLE_CLAUDEAI_MCP_SERVERS=$want_mcp settings=$want_settings deny=$want_deny" ] ||
      wrong="$wrong$role $line"$'\n'
  done <"$log"
  printf '%s' "$wrong"
  check "profiles: every pass has one lean deny flag, its settings count, the 5m cache and connectors off outside autoreview" [ -z "$wrong" ]
  [ $# -ne 0 ] || for role in VALIDATOR PHASEA_ONLY QUALITY THERMO AUTOREVIEW; do
    check "profiles: a $role pass was logged" grep -q "^$role " "$log"
  done
}
check_pass_profiles "$@"

if [ "$failures" -ne 0 ]; then
  printf 'PR review flow smoke test: %s failure(s)\n' "$failures"
  exit 1
fi
printf 'PR review flow smoke test: ok\n'
