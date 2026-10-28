#!/bin/bash

PR_REVIEW_USAGE_LOG="${PR_REVIEW_USAGE_LOG:-$HOME/.claude/logs/pr-review-usage.log}"
REVIEW_VETO_RC=3
REVIEW_INCOMPLETE_RC=4
VERIFY_UNCONFIGURED_RC=5
CLAUDE_PASS_TIMEOUT="${PR_REVIEW_PASS_TIMEOUT:-2700}"
CLAUDE_MAX_TURNS="${PR_REVIEW_MAX_TURNS:-200}"
CLAUDE_MAX_BUDGET_USD="${PR_REVIEW_MAX_BUDGET_USD:-25}"
STOP_GRACE_SECONDS="${PR_REVIEW_STOP_GRACE:-10}"
AUTO_PROFILE=(--permission-mode auto --permission-prompts none)
READ_ONLY_PROFILE=("${AUTO_PROFILE[@]}" --disallowedTools=Edit,Write,NotebookEdit)
ISOLATED_SETTINGS=(--settings '{"disableAllHooks":true}' --strict-mcp-config --setting-sources project,local)
USAGE_TARGET="${USAGE_TARGET:-}"
export GIT_TERMINAL_PROMPT=0
. "$(dirname "${BASH_SOURCE[0]}")/../claude-bin.sh"
CLAUDE="${PR_COUNCIL_CLAUDE:-$CLAUDE}"
CODEX="${PR_COUNCIL_CODEX:-}"
if [ -z "$CODEX" ]; then
  for candidate in "$HOME/.local/share/fnm/aliases/default/bin/codex" "$HOME/.local/bin/codex" "$(command -v codex 2>/dev/null)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] && { CODEX="$candidate"; break; }
  done
fi
# The fix-verification skill is machine-local: PR_COUNCIL_VERIFY_SKILL, else the first line of
# ~/.config/pr-council-review/verify-skill. Prints `/<name>`; fails when unset or malformed.
verify_skill() {
  local name="${PR_COUNCIL_VERIFY_SKILL:-}"
  [ -n "$name" ] || name="$(head -1 "$HOME/.config/pr-council-review/verify-skill" 2>/dev/null)"
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"
  name="${name#/}"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9:_-]*$ ]] || return 1
  printf '/%s' "$name"
}

AUTHOR_CONFIG_PATHS=(CLAUDE.md CLAUDE.local.md AGENTS.md AGENTS.override.md .mcp.json .claude .codex ':(glob)**/CLAUDE.md' ':(glob)**/CLAUDE.local.md' ':(glob)**/AGENTS.md' ':(glob)**/AGENTS.override.md' ':(glob)**/.claude/**' ':(glob)**/.codex/**')

render_template() {
  local file="$1"
  shift
  env "${@/#/T_}" perl -0pe 's/\{\{(\w+)\}\}/exists $ENV{"T_$1"} ? $ENV{"T_$1"} : $&/ge' "$file"
}

# Reset every agent config file (CLAUDE.md, AGENTS.md and their local/override variants, .claude, .codex, .mcp.json) in the
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
  local outcome
  if ! outcome="$(jq -r 'if type != "object" then error("not an envelope")
      elif .is_error == false and .subtype == "success" and (.result | type) == "string" and .result != ""
      then "complete" else "is_error=\(.is_error) subtype=\(.subtype)" end' "$1" 2>/dev/null)" || [ -z "$outcome" ]; then
    echo "=== could not parse the session output as JSON; raw output follows" >&2
    cat "$1"
    return 1
  fi
  if [ "$outcome" != complete ]; then
    echo "=== the session ended without a complete result ($outcome)" >&2
    jq -r '.result // empty' "$1"
    return 2
  fi
  jq -r .result "$1"
}

check_denials() {
  local count denials
  if ! count="$(jq -e '.permission_denials | if type == "array" then length else error("not an array") end' "$1" 2>/dev/null)" \
    || ! denials="$(jq -r '.permission_denials[] | "\(.tool_name): \(.tool_input.command // .tool_input.file_path // (.tool_input | tostring))"' "$1" 2>/dev/null)"; then
    echo "=== cannot read permission denials from $1, the pass is unverified" >&2
    return 2
  fi
  [ "$count" -gt 0 ] || return 0
  echo "=== $count permission denial(s), the pass is incomplete:" >&2
  printf '%s\n' "$denials" >&2
  return 1
}

usage_line() {
  jq -r --arg label "$2" --arg version "$3" '"=== usage \($label): claude_version=\($version) turns=\(.num_turns // "?") subtype=\(.subtype // "?") cost=\(.total_cost_usd // "?") denials=\(.permission_denials | length? // "?") | " + ([.modelUsage // {} | to_entries[] | "\(.key) in=\(.value.inputTokens) cache_write=\(.value.cacheCreationInputTokens) cache_read=\(.value.cacheReadInputTokens) out=\(.value.outputTokens)"] | join(" | "))' "$1" 2>/dev/null
}

# $1 session JSON, $2 the pass's exit code: a denied pass always vetoes the
# council; an unverified one only when its report is used (exit 0).
denial_veto() {
  local rc=0
  check_denials "$1" || rc=$?
  [ "$rc" -eq 1 ] || { [ "$rc" -eq 2 ] && [ "$2" -eq 0 ]; }
}

record_usage() {
  local raw="$1" label="$2" target="$3" line
  [ -n "${CLAUDE_VERSION:-}" ] || CLAUDE_VERSION="$("$CLAUDE" --version 2>/dev/null | awk 'NR == 1 { print $1 }')"
  line="$(usage_line "$raw" "$label" "${CLAUDE_VERSION:-unknown}")" || return 0
  [ -n "$line" ] || return 0
  echo "$line"
  mkdir -p "$(dirname "$PR_REVIEW_USAGE_LOG")"
  printf '%s\t%s\t%s\n' "$(date '+%F %T')" "$target" "${line#=== usage }" >>"$PR_REVIEW_USAGE_LOG"
}

patch_id() { git diff --binary "$1" "$2" | git patch-id --verbatim | cut -d' ' -f1; }

# same_patch <base ref> <old sha> <new sha>: both carry the same changes on their
# own merge base with the base ref (a rebase or a base merge without new work).
same_patch() {
  local old_id new_id
  old_id="$(patch_id "$(git merge-base "$1" "$2")" "$2")" && new_id="$(patch_id "$(git merge-base "$1" "$3")" "$3")" \
    && [ -n "$old_id" ] && [ "$old_id" = "$new_id" ]
}

stop_group() {
  kill -TERM -- "-$1" 2>/dev/null
  perl -e 'my ($g, $t) = @ARGV; for (1 .. 10 * $t) { kill(0, -$g) or exit; select(undef, undef, undef, 0.1) } kill "KILL", -$g' "$1" "$STOP_GRACE_SECONDS"
}

stop_children() {
  local child
  for child in $(pgrep -P $$); do
    kill_tree "$child" TERM
  done
}

# Runs the command in its own process group; on INT, TERM or HUP, or at the timeout
# (INT, then TERM, then KILL), the whole group stops. Returns 124 on a timeout.
run_with_timeout() {
  local timeout="$1" pid watchdog expired rc=0 saved
  shift
  expired="$(mktemp "${TMPDIR:-/tmp}/run-timeout.XXXXXX")" && rm -f "$expired"
  saved="$(trap -p INT TERM HUP)"
  perl -e '$SIG{INT} = $SIG{QUIT} = "DEFAULT"; setpgrp(0, 0); exec @ARGV or die "exec: $!"' "$@" &
  pid=$!
  perl -e 'my ($t, $g, $grace, $flag) = @ARGV; sleep $t; open my $fh, ">", $flag; close $fh;
    for my $signal ("INT", "TERM") { kill $signal, -$g; for (1 .. 10 * $grace) { kill(0, -$g) or exit; select(undef, undef, undef, 0.1) } }
    kill "KILL", -$g' "$timeout" "$pid" "$STOP_GRACE_SECONDS" "$expired" </dev/null &
  watchdog=$!
  trap 'kill "$watchdog" 2>/dev/null; stop_group "$pid"; exit 130' INT
  trap 'kill "$watchdog" 2>/dev/null; stop_group "$pid"; exit 143' TERM
  trap 'kill "$watchdog" 2>/dev/null; stop_group "$pid"; exit 129' HUP
  wait "$pid" || rc=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  trap - INT TERM HUP
  eval "$saved"
  if [ -e "$expired" ]; then
    rm -f "$expired"
    kill -KILL -- "-$pid" 2>/dev/null
    echo "=== timeout after ${timeout}s, process group $pid stopped" >&2
    return 124
  fi
  return "$rc"
}

# claude_pass <label> <session json> <read-only|auto> <prompt> [flags]: prints the result; returns 0,
# REVIEW_VETO_RC on a denial, REVIEW_INCOMPLETE_RC on an error or cap hit, else the claude exit code
# (1 when claude exited 0 without a session envelope).
claude_pass() {
  local label="$1" raw="$2" profile="$3" prompt="$4" rc=0 result_rc=0
  shift 4
  [ -n "$CLAUDE" ] || { echo "=== $label: claude binary not found" >&2; return 1; }
  case "$profile" in
    read-only) set -- "${READ_ONLY_PROFILE[@]}" "$@" ;;
    auto) set -- "${AUTO_PROFILE[@]}" "$@" ;;
    *) echo "=== $label: unknown profile $profile" >&2; return 1 ;;
  esac
  run_with_timeout "$CLAUDE_PASS_TIMEOUT" "$CLAUDE" -p "$prompt" --output-format json \
    --max-turns "$CLAUDE_MAX_TURNS" --max-budget-usd "$CLAUDE_MAX_BUDGET_USD" "$@" </dev/null >"$raw" 2>"$raw.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "=== $label: claude exited $rc; stderr tail:" >&2
    tail -n 20 "$raw.err" >&2
  fi
  extract_result "$raw" || result_rc=$?
  record_usage "$raw" "$label" "$USAGE_TARGET" >&2
  if [ "$result_rc" -eq 1 ]; then
    [ "$rc" -eq 0 ] && return 1
    return "$rc"
  fi
  if denial_veto "$raw" "$rc"; then return "$REVIEW_VETO_RC"; fi
  [ "$result_rc" -ne 2 ] || return "$REVIEW_INCOMPLETE_RC"
  [ "$rc" -eq 0 ] || return "$rc"
}

# codex_pass <worktree> <report> <model> <effort> <prompt>: one read-only codex exec run
# without user config (MCP servers, profiles); its final message goes to the report.
codex_pass() {
  local tree="$1" report="$2" model="$3" effort="$4" prompt="$5" rc=0
  run_with_timeout "$CLAUDE_PASS_TIMEOUT" "$CODEX" exec --cd "$tree" --sandbox read-only \
    --ignore-user-config --ephemeral --color never --model "$model" \
    -c model_reasoning_effort="\"$effort\"" --output-last-message "$report" "$prompt" \
    </dev/null >"$report.log" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ] && [ ! -s "$report" ]; then
    echo "=== codex: exited 0 without a final message" >&2
    rc=1
  fi
  if [ "$rc" -ne 0 ]; then
    echo "=== codex: exited $rc; log tail:" >&2
    tail -n 20 "$report.log" >&2
  fi
  return "$rc"
}

acquire_lock() {
  local lock="$1" holder_pattern="$2" holder
  for _ in 1 2; do
    if mkdir "$lock" 2>/dev/null; then
      echo $$ >"$lock/pid"
      return 0
    fi
    holder="$(cat "$lock/pid" 2>/dev/null)"
    if [ -n "$holder" ]; then
      ps -p "$holder" -o command= 2>/dev/null | grep -q -- "$holder_pattern" && return 1
    elif [ "$(perl -e 'print time - ((stat shift)[9] // 0)' "$lock")" -lt 60 ]; then
      return 1
    fi
    rm -rf "$lock"
  done
  return 1
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

phase_b_output() {
  awk '/^=== phase B: / { text = ""; seen = 1; next } seen { text = text $0 "\n" } END { printf "%s", text }' "$1" 2>/dev/null
}

validator_run_findings() {
  phase_b_output "$1" | grep -o '"kind":"run"[^>]*' | grep -F "\"sha\":\"$2\"" | tail -1 | sed -n 's/.*"findings":\([0-9]*\).*/\1/p'
}

validator_marker_json() {
  local raw
  raw="$(phase_b_output "$1" | grep -o '"kind":"run"[^>]*' | grep -F "\"sha\":\"$2\"" | tail -1)"
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
