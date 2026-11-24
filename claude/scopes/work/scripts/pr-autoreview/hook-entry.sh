#!/bin/sh

[ "${hook_name:-$(basename -- "$0")}" = "pre-push" ] || return 0
[ -z "${PR_AUTOREVIEW_DISABLED:-}" ] || return 0
[ -f "$HOME/.claude/state/pr-autoreview.off" ] && return 0

pr_autoreview_remote_url="${2:-}"
pr_autoreview_repos="$HOME/.claude/state/pr-autoreview/repos.tsv"
[ -r "$pr_autoreview_repos" ] || return 0

pr_autoreview_repo=$(printf '%s' "$pr_autoreview_remote_url" | sed -E -e 's,\.git$,,' -e 's,^.*[:/]([^/]+/[^/]+)$,\1,')
pr_autoreview_profile=$(awk -F'\t' -v r="$pr_autoreview_repo" '$1 == r { print $2; exit }' "$pr_autoreview_repos")
[ -n "$pr_autoreview_profile" ] || return 0
pr_autoreview_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0

# Fleet reviews only the PR on the branch checked out in a thread's own
# worktree, a directory named by the thread id, through the watcher dry-run:
# skip just that branch, pushed from that worktree to its origin repo. Any
# other push from the pane still gets an autoreview.
pr_autoreview_fleet_branch=""
if [ -n "${FLEET_THREAD:-}" ] && [ "$(basename -- "$pr_autoreview_root")" = "$FLEET_THREAD" ]; then
  pr_autoreview_origin_url=$(git remote get-url origin 2>/dev/null || true)
  pr_autoreview_origin_repo=$(printf '%s' "$pr_autoreview_origin_url" | sed -E -e 's,\.git$,,' -e 's,^.*[:/]([^/]+/[^/]+)$,\1,')
  if [ -n "$pr_autoreview_origin_repo" ] && [ "$pr_autoreview_origin_repo" = "$pr_autoreview_repo" ]; then
    pr_autoreview_fleet_branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || true)
  fi
fi

pr_autoreview_refs=$(mktemp "${TMPDIR:-/tmp}/pr-autoreview-refs.XXXXXX") || return 0
cat >"$pr_autoreview_refs"

while read -r pr_autoreview_local_ref pr_autoreview_local_sha pr_autoreview_remote_ref pr_autoreview_remote_sha; do
  case "$pr_autoreview_local_sha" in
    ''|0000000000000000000000000000000000000000) continue ;;
  esac
  pr_autoreview_branch="${pr_autoreview_remote_ref#refs/heads/}"
  [ "$pr_autoreview_branch" != "$pr_autoreview_remote_ref" ] || continue
  case "$pr_autoreview_branch" in
    main|master|develop) continue ;;
  esac
  [ -z "$pr_autoreview_fleet_branch" ] || [ "$pr_autoreview_branch" != "$pr_autoreview_fleet_branch" ] || continue

  nohup "$HOME/.claude/scripts/pr-autoreview/run.sh" \
    "$pr_autoreview_repo" \
    "$pr_autoreview_profile" \
    "$pr_autoreview_branch" \
    "$pr_autoreview_local_sha" \
    "$pr_autoreview_root" \
    >/dev/null 2>&1 &
done <"$pr_autoreview_refs"

exec <"$pr_autoreview_refs"
rm -f "$pr_autoreview_refs"

return 0
