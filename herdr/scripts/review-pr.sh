#!/bin/sh
bin="${HERDR_BIN_PATH:-herdr}"
fail() { printf '%s\n' "$1"; sleep 5; exit 1; }

tmpl="$1"
[ -n "$tmpl" ] || tmpl='/code-review-inline {pr}'

printf 'PR id or url: '
read -r input
[ -n "$input" ] || exit 0

parsed=$(python3 -c '
import re, sys
s = sys.argv[1].strip()
m = re.match(r"^(?:https?://)?(?:www\.)?github\.com/([^/]+)/([^/?#]+)/pull/(\d+)", s)
if m:
    print(m.group(3), m.group(1) + "/" + m.group(2))
else:
    n = s.lstrip("#")
    if not n.isdigit():
        sys.exit(1)
    print(n, "")
' "$input") || fail "not a PR id or github PR url: $input"

id=${parsed%% *}
repo=${parsed#* }

cd "${HERDR_ACTIVE_PANE_CWD:-$PWD}" || fail "bad cwd"

if [ -n "$repo" ]; then
  here=$(gh repo view --json nameWithOwner | python3 -c 'import json,sys;print(json.load(sys.stdin)["nameWithOwner"])') \
    || fail "not a github repo here"
  [ "$(printf '%s' "$repo" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$here" | tr 'A-Z' 'a-z')" ] \
    || fail "PR is on $repo, this workspace is $here"
fi

info=$(gh pr view "$id" --json headRefName,title) || fail "gh pr view $id failed"
head=$(printf '%s' "$info" | python3 -c 'import json,sys;print(json.load(sys.stdin)["headRefName"])')
title=$(printf '%s' "$info" | python3 -c 'import json,sys;print(json.load(sys.stdin)["title"])' | tr -cs 'A-Za-z0-9 ._-' ' ' | cut -c1-32)

printf 'PR #%s <- %s\n' "$id" "$head"
git fetch -f origin "refs/pull/$id/head:refs/heads/pr/$id" || fail "fetch pr/$id failed"

if [ -n "$HERDR_ACTIVE_WORKSPACE_ID" ]; then
  set -- --workspace "$HERDR_ACTIVE_WORKSPACE_ID"
else
  set -- --cwd "$PWD"
fi
out=$("$bin" worktree create "$@" --branch "pr/$id" --label "review $id $title" --focus --json) || fail "$out"

pane=$(printf '%s' "$out" | grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$pane" ] || fail "no pane in: $out"

prompt=$(printf '%s' "$tmpl" | sed -e "s|{pr}|$id|g" -e "s|{branch}|$head|g")
"$bin" pane run "$pane" "claude '$prompt'"
