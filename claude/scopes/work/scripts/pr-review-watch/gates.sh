#!/bin/bash

CI_WAIT_SECONDS="${PR_REVIEW_WATCH_CI_WAIT:-1800}"
ALLOW_NO_CI="${PR_REVIEW_WATCH_ALLOW_NO_CI:-0}"
KILL_SWITCH_FILE="${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}/off"

field() {
  grep -E "^$2 " "$1" | tail -1 | tr ' ' '\n' | sed -n "s/^$3=//p"
}

unresolved_threads() {
  local out
  out="$(gh api graphql --paginate -F owner="${REPO%/*}" -F name="${REPO#*/}" -F number="$NUMBER" -f query='
    query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $endCursor) {
            nodes { isResolved }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not) | 1')" || return 1
  printf '%s' "$out" | grep -c . || true
}

pr_state_line() {
  gh pr view "$NUMBER" --repo "$REPO" --json state,isDraft,headRefOid,latestReviews \
    | jq -r --arg me "$ME" '[
        .state, .isDraft, .headRefOid,
        ([.latestReviews[] | select(.state == "CHANGES_REQUESTED" and .author.login != $me) | .author.login] | join(","))
      ] | @tsv'
}

ci_state() {
  local buckets
  buckets="$(gh pr checks "$NUMBER" --repo "$REPO" --json bucket --jq '[.[].bucket] | unique | join(",")' 2>/dev/null)" \
    || { echo unknown; return; }
  case ",$buckets," in
    ,,) echo none ;;
    *,fail,*|*,cancel,*) echo fail ;;
    *,pending,*) echo pending ;;
    *) echo pass ;;
  esac
}

wait_for_ci() {
  local waited=0 state
  state="$(ci_state)"
  while { [ "$state" = pending ] || [ "$state" = none ]; } && [ "$waited" -lt "$CI_WAIT_SECONDS" ]; do
    [ -f "$KILL_SWITCH_FILE" ] && { echo stopped; return; }
    sleep 60
    waited=$((waited + 60))
    state="$(ci_state)"
  done
  [ "$state" = none ] && [ "$ALLOW_NO_CI" = 1 ] && state=pass
  echo "$state"
}

pr_blocker() {
  local state draft head others threads
  IFS=$'\t' read -r state draft head others <<<"$(pr_state_line 2>/dev/null)"
  [ "$state" = OPEN ] || { echo "PR is ${state:-unreadable}"; return; }
  [ "$draft" = false ] || { echo "PR is a draft"; return; }
  [ "$head" = "$SHA" ] || { echo "head moved to ${head:0:8}"; return; }
  [ -z "$others" ] || { echo "changes requested by $others"; return; }
  threads="$(unresolved_threads 2>/dev/null)"
  [ "$threads" = 0 ] || { echo "${threads:-unknown} unresolved review threads"; return; }
}

objective_blocker() {
  local blocker ci
  [ -f "$KILL_SWITCH_FILE" ] && { echo "kill switch is on"; return; }
  blocker="$(pr_blocker)"
  [ -z "$blocker" ] || { echo "$blocker"; return; }
  ci="$(wait_for_ci)"
  [ "$ci" = pass ] || { echo "CI is $ci"; return; }
  [ -f "$KILL_SWITCH_FILE" ] && { echo "kill switch is on"; return; }
  pr_blocker
}

verify_blocker() {
  local log="$1" delta_findings="$2" reviewed
  [ "${delta_findings:-x}" = 0 ] || { echo "delta review posted ${delta_findings:-unknown} findings"; return; }
  grep -qE '^VERIFY_VERDICT ' "$log" || { echo "no VERIFY_VERDICT line"; return; }
  reviewed="$(field "$log" VERIFY_VERDICT reviewed)"
  [ "$reviewed" -ge 0 ] 2>/dev/null || { echo "unreadable finding count"; return; }
  [ "$reviewed" -ge 1 ] || [ -f "$KEY.council-clean" ] || { echo "no finding was verified"; return; }
  [ "$(field "$log" VERIFY_VERDICT reopened)" = 0 ] || { echo "findings reopened"; return; }
  [ "$(field "$log" VERIFY_VERDICT regressions)" = 0 ] || { echo "regressions raised"; return; }
  [ "$(field "$log" VERIFY_VERDICT complete)" = true ] || { echo "finding set incomplete"; return; }
  [ "$(field "$log" VERIFY_VERDICT confident)" = true ] || { echo "reviewer not confident"; return; }
}

clean_blocker() {
  local log="$1" delta_findings="$2"
  [ "${delta_findings:-x}" = 0 ] || { echo "delta review posted ${delta_findings:-unknown} findings"; return; }
  [ "$(field "$log" DELTA_CONFIDENT value)" = true ] || { echo "reviewer not confident"; return; }
}
