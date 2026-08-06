#!/usr/bin/env bash
set -u

pull=0
if [ "${1:-}" = "--pull" ]; then
  pull=1
elif [ "${1:-}" != "" ]; then
  echo "usage: source-gate.sh [--pull]" >&2
  exit 2
fi

fail=0

trusted_branch() {
  case "$1" in
    main|master|release-*) return 0 ;;
    *) return 1 ;;
  esac
}

check_repo_exists() {
  if ! git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "FAIL $2: not a git repo at $1"
    fail=1
    return 1
  fi
  return 0
}

check_readonly_repo() {
  repo="$1"
  name="$2"

  check_repo_exists "$repo" "$name" || return
  cd "$repo" || {
    echo "FAIL $name: cannot cd to $repo"
    fail=1
    return
  }

  dirty="$(git status --porcelain)"
  if [ "$dirty" != "" ]; then
    echo "FAIL $name: dirty worktree"
    fail=1
    return
  fi

  branch="$(git branch --show-current)"
  if ! trusted_branch "$branch"; then
    echo "FAIL $name: branch '$branch' is not main/master/release-*"
    fail=1
    return
  fi

  if ! git fetch origin "$branch" --quiet; then
    echo "FAIL $name: cannot fetch origin/$branch"
    fail=1
    return
  fi

  if ! git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    echo "FAIL $name: missing origin/$branch"
    fail=1
    return
  fi

  head="$(git rev-parse HEAD)"
  remote="$(git rev-parse "origin/$branch")"
  base="$(git merge-base HEAD "origin/$branch")"

  if [ "$head" = "$remote" ]; then
    echo "PASS $name: $branch synced"
    return
  fi

  if [ "$head" = "$base" ]; then
    if [ "$pull" -eq 1 ]; then
      if git pull --ff-only origin "$branch" --quiet; then
        if [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$branch")" ]; then
          echo "PASS $name: $branch fast-forwarded and synced"
          return
        fi
      fi
      echo "FAIL $name: fast-forward pull failed"
      fail=1
      return
    fi
    echo "FAIL $name: behind origin/$branch (rerun with --pull or update manually)"
    fail=1
    return
  fi

  echo "FAIL $name: local branch is ahead or diverged from origin/$branch"
  fail=1
}

check_agent_repo() {
  repo="$1"
  name="agent-nodejs"

  check_repo_exists "$repo" "$name" || return
  cd "$repo" || {
    echo "FAIL $name: cannot cd to $repo"
    fail=1
    return
  }

  if ! git fetch origin main --quiet; then
    echo "FAIL $name: cannot fetch origin/main"
    fail=1
    return
  fi

  branch="$(git branch --show-current)"
  dirty="$(git status --porcelain)"
  if [ "$dirty" != "" ]; then
    echo "FAIL $name: dirty worktree; commit or stash before sourcing file:line evidence"
    echo "$dirty"
    fail=1
    return
  fi

  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    base="$(git merge-base HEAD origin/main)"
    behind="$(git rev-list --count "$base"..origin/main)"
    ahead="$(git rev-list --count origin/main..HEAD)"
    echo "PASS $name: branch '$branch', ahead origin/main by $ahead, base behind origin/main by $behind"
  else
    echo "FAIL $name: missing origin/main"
    fail=1
  fi
}

check_readonly_repo "$HOME/work/employer-server" "employer-server"
check_readonly_repo "$HOME/work/employer-bugfixes" "employer-bugfixes"
check_readonly_repo "$HOME/work/zendesk/employer-for-zendesk" "employer-for-zendesk"
check_agent_repo "$HOME/work/agent-nodejs"

exit "$fail"
