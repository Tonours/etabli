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
