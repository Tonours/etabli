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
  if command -v terminal-notifier >/dev/null; then
    terminal-notifier -group "pr-review-$3" -title "$1" -message "$2" -open "$3" >/dev/null 2>&1
  else
    osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1
  fi
}

validator_run_findings() {
  grep -o '"kind":"run"[^>]*' "$1" 2>/dev/null | grep -F "\"sha\":\"$2\"" | tail -1 | sed -n 's/.*"findings":\([0-9]*\).*/\1/p'
}
