#!/bin/bash

PR_REVIEW_USAGE_LOG="${PR_REVIEW_USAGE_LOG:-$HOME/.claude/logs/pr-review-usage.log}"
AUTHOR_CONFIG_PATHS=(CLAUDE.md AGENTS.md .mcp.json .claude ':(glob)**/CLAUDE.md' ':(glob)**/AGENTS.md' ':(glob)**/.claude/**')

render_template() {
  local file="$1"
  shift
  env "${@/#/T_}" perl -0pe 's/\{\{(\w+)\}\}/exists $ENV{"T_$1"} ? $ENV{"T_$1"} : $&/ge' "$file"
}

# Reset every agent config file (CLAUDE.md, AGENTS.md, .claude, .mcp.json) in the
# worktree to its version in the trusted commit (default: the staged base), wherever in
# the PR history it was changed. Paths stay staged against the base so the review diff
# does not show them.
neutralize_author_config() {
  local tree="$1" base="$2" trusted="${3:-$2}" path count=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if git -C "$tree" cat-file -e "$trusted:$path" 2>/dev/null; then
      git -C "$tree" checkout -q "$trusted" -- "$path"
    else
      git -C "$tree" rm -q -f --ignore-unmatch -- "$path" >/dev/null
      rm -f -- "$tree/$path"
    fi
    count=$((count + 1))
  done < <(git -C "$tree" diff --name-only "$trusted" -- "${AUTHOR_CONFIG_PATHS[@]}")
  if [ "$trusted" != "$base" ]; then
    git -C "$tree" reset -q "$base" -- "${AUTHOR_CONFIG_PATHS[@]}" >/dev/null 2>&1
  fi
  [ "$count" -eq 0 ] || echo "=== $count agent config files changed by the PR were reset to the base version and are not reviewed"
}

extract_result() {
  if ! jq -er '.result // empty' "$1" 2>/dev/null; then
    echo "=== could not parse the session output as JSON; raw output follows" >&2
    cat "$1"
    return 1
  fi
}

check_denials() {
  local denials
  if ! jq -e 'type == "object"' "$1" >/dev/null 2>&1 \
    || ! denials="$(jq -r '.permission_denials[]? | "\(.tool_name): \(.tool_input.command // .tool_input.file_path // (.tool_input | tostring))"' "$1" 2>/dev/null)"; then
    echo "=== cannot read permission denials from $1, the pass is unverified" >&2
    return 2
  fi
  [ -n "$denials" ] || return 0
  echo "=== $(printf '%s\n' "$denials" | wc -l | tr -d ' ') permission denial(s), the pass is incomplete:" >&2
  printf '%s\n' "$denials" >&2
  return 1
}

usage_line() {
  jq -r --arg label "$2" '"=== usage \($label): " + ([.modelUsage // {} | to_entries[] | "\(.key) in=\(.value.inputTokens) cache_write=\(.value.cacheCreationInputTokens) cache_read=\(.value.cacheReadInputTokens) out=\(.value.outputTokens)"] | join(" | ")) + " | api_equiv_usd=\(.total_cost_usd // "?")"' "$1" 2>/dev/null
}

record_usage() {
  local raw="$1" label="$2" target="$3" line
  line="$(usage_line "$raw" "$label")" || return 0
  [ -n "$line" ] || return 0
  echo "$line"
  mkdir -p "$(dirname "$PR_REVIEW_USAGE_LOG")"
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$target" "${line#=== usage }" >>"$PR_REVIEW_USAGE_LOG"
}

kill_tree() {
  local pid="$1" signal="${2:-TERM}" child
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    kill_tree "$child" "$signal"
  done
  kill "-$signal" "$pid" 2>/dev/null
}

strip_control_chars() {
  LC_ALL=C tr -d '\000-\010\013-\037\177'
}

purge_old_dirs() {
  local parent="$1" pattern="$2" days="$3"
  find "$parent" -maxdepth 1 -type d -name "$pattern" -mtime "+$days" -exec rm -rf {} + 2>/dev/null
}

notify() {
  if ! terminal-notifier -group "pr-review-$3" -title "$1" -message "$2" -open "$3" >/dev/null 2>&1; then
    osascript -e "display notification \"${2//\"/}\" with title \"${1//\"/}\"" >/dev/null 2>&1
  fi
  return 0
}

validator_run_findings() {
  grep -o '"kind":"run"[^>]*' "$1" 2>/dev/null | grep -F "\"sha\":\"$2\"" | tail -1 | sed -n 's/.*"findings":\([0-9]*\).*/\1/p'
}

session_run_marker() {
  local raw="$1" sha="$2" session transcript
  session="$(jq -r '.session_id // empty' "$raw" 2>/dev/null)"
  [ -n "$session" ] || return 0
  transcript="$(find "$HOME/.claude/projects" -maxdepth 2 -name "$session.jsonl" 2>/dev/null | head -1)"
  [ -n "$transcript" ] || return 0
  grep -o '"kind\\":\\"run\\"[^>]*' "$transcript" | sed 's/\\"/"/g' | grep -F "\"sha\":\"$sha\"" | tail -1 | sed 's/^/claudine:v1 {/'
}

validator_marker_json() {
  local raw
  raw="$(grep -o '"kind":"run"[^>]*' "$1" 2>/dev/null | grep -F "\"sha\":\"$2\"" | tail -1)"
  [ -n "$raw" ] || return 1
  raw="{$raw"
  raw="$(printf '%s' "$raw" | sed -E 's/[[:space:]-]+$//')"
  printf '%s' "$raw" | jq -e . >/dev/null 2>&1 || return 1
  printf '%s' "$raw"
}

validator_approval_body() {
  local marker blocker
  marker="$(validator_marker_json "$1" "$2")" || { echo "no validator run marker for ${2:0:8}" >&2; return 1; }
  blocker="$(printf '%s' "$marker" | jq -r '
    if .findings != 0 then "validator posted \(.findings) findings"
    elif .security == "ticketed" then "a security finding waits on a ticket"
    elif ([.lenses[]?] | index("pending")) != null then "a validator lens is still pending"
    else empty end')"
  [ -z "$blocker" ] || { echo "$blocker" >&2; return 1; }
  printf 'Approved after /validator run %s: nothing at or above `%s` posted, %s suppressed.\n<!-- claudine:v1 %s -->' \
    "$(printf '%s' "$marker" | jq -r .run)" "$(printf '%s' "$marker" | jq -r .floor)" \
    "$(printf '%s' "$marker" | jq -r .suppressed)" "$marker"
}
