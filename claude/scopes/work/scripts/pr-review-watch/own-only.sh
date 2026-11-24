#!/bin/bash

# Own-only mode is the `own-only` file in the watcher state folder. A file, not an
# environment variable, so launchers written before the switch obey it too.

own_only_state_dir() { printf '%s' "${PR_REVIEW_WATCH_STATE_DIR:-$HOME/.claude/state/pr-review-watch}"; }

own_only() {
  local file
  file="$(own_only_state_dir)/own-only"
  [ -e "$file" ] || [ -L "$file" ]
}

own_only_gh() {
  PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH" \
    perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "${PR_REVIEW_WATCH_GH_TIMEOUT:-60}" gh "$@"
}

own_only_login() {
  local login
  login="$(own_only_gh api user --jq .login </dev/null 2>/dev/null)" || return 1
  [ -n "$login" ] || return 1
  printf '%s' "$login" | tr '[:upper:]' '[:lower:]'
}

pr_author_login() {
  local login
  login="$(own_only_gh pr view "$2" --repo "$1" --json author --jq '.author.login // empty' </dev/null 2>/dev/null)" || return 1
  [ -n "$login" ] || return 1
  printf '%s' "$login" | tr '[:upper:]' '[:lower:]'
}

# GitHub account node ids never change or move to another account, unlike logins.
pr_author_id() {
  local id
  id="$(own_only_gh pr view "$2" --repo "$1" --json author --jq '.author.id // empty' </dev/null 2>/dev/null)" || return 1
  [[ "$id" =~ ^[A-Za-z0-9_=-]+$ ]] || return 1
  printf '%s' "$id"
}

own_only_account_id() {
  local id
  id="$(own_only_gh api user --jq '.node_id // empty' </dev/null 2>/dev/null)" || return 1
  [[ "$id" =~ ^[A-Za-z0-9_=-]+$ ]] || return 1
  printf '%s' "$id"
}

own_only_key_pr() {
  local base="${1##*/}"
  [[ "$base" =~ ^([A-Za-z0-9-]+)_(.+)_([0-9]+)$ ]] || return 1
  printf '%s/%s %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
}

# 1: allowed; 0: refused; 2: refused for now, the login or the author could not be read.
own_only_refused() {
  local repo="$1" number="$2" mode="$3" me author
  own_only || return 1
  [ "$mode" = dryrun ] || { echo "own-only: mode $mode refused for $repo#$number" >&2; return 0; }
  if ! me="$(own_only_login)" || ! author="$(pr_author_login "$repo" "$number")"; then
    echo "own-only: author of $repo#$number unreadable, deferred" >&2
    return 2
  fi
  [ "$me" = "$author" ] && return 1
  echo "own-only: $repo#$number is another author's pull request" >&2
  return 0
}

own_only_refused_key() {
  local pair
  own_only || return 1
  pair="$(own_only_key_pr "$1")" || { echo "own-only: unreadable run key" >&2; return 0; }
  own_only_refused "${pair% *}" "${pair#* }" "$2"
}
