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
export PR_COUNCIL_CLAUDE="$HOME/.local/bin/claude" PR_REVIEW_WATCH_CLAUDE="$HOME/.local/bin/claude"
export PR_REVIEW_WATCH_CI_WAIT=0 PR_REVIEW_USAGE_LOG="$TMP_DIR/usage.log"
mkdir -p "$TMPDIR" "$HOME/.local/bin" "$HOME/.claude/skills/thermo-nuclear-code-quality-review" "$FAKE_DIR" "$GH_CONFIG_DIR"
echo "thermo stub" >"$HOME/.claude/skills/thermo-nuclear-code-quality-review/SKILL.md"

cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
printf 'gh %s\n' "$*" >>"$FAKE_LOG"
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
printf 'claude %s %s\n' "$role" "${flags[*]}" >>"$FAKE_LOG"
envelope_var="FAKE_${role}_ENVELOPE" text_var="FAKE_${role}_TEXT" rc_var="FAKE_${role}_RC"
envelope="$FAKE_FIXTURES/2.1.308-${!envelope_var:-success}.json"
text="${!text_var:-}"
out="$(jq --arg t "${text//\{\{SHA\}\}/$FAKE_HEAD}" 'if (.result | type) == "string" and $t != "" then .result = $t else . end' "$envelope")"
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

case_clean_council_approves
case_council_findings_wait
case_phase_a_denial_vetoes
case_verify_after_findings_approves

if [ "$failures" -ne 0 ]; then
  printf 'PR review flow smoke test: %s failure(s)\n' "$failures"
  exit 1
fi
printf 'PR review flow smoke test: ok\n'
