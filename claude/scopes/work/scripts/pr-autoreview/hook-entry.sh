#!/bin/sh

[ "${hook_name:-}" = "pre-push" ] || return 0
[ -z "${PR_AUTOREVIEW_DISABLED:-}" ] || return 0
[ -f "$HOME/.claude/state/pr-autoreview.off" ] && return 0

pr_autoreview_remote_url="${2:-}"
case "$pr_autoreview_remote_url" in
  *employer/agent-nodejs*|\
  *employer/employer-server*|\
  *employer/employer.git*|\
  *employer/employer|\
  *employer/employer-for-zendesk*) ;;
  *) return 0 ;;
esac

pr_autoreview_repo=$(printf '%s' "$pr_autoreview_remote_url" | sed -e 's,.*employer/,,' -e 's,\.git$,,')
pr_autoreview_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0

while read -r pr_autoreview_local_ref pr_autoreview_local_sha pr_autoreview_remote_ref pr_autoreview_remote_sha; do
  case "$pr_autoreview_local_sha" in
    ''|0000000000000000000000000000000000000000) continue ;;
  esac

  pr_autoreview_branch=$(printf '%s' "$pr_autoreview_local_ref" | sed 's,refs/heads/,,')
  case "$pr_autoreview_branch" in
    main|master|develop) continue ;;
  esac

  nohup "$HOME/.claude/scripts/pr-autoreview/run.sh" \
    "$pr_autoreview_repo" \
    "$pr_autoreview_branch" \
    "$pr_autoreview_local_sha" \
    "$pr_autoreview_root" \
    >/dev/null 2>&1 &
done

return 0
