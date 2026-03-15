#!/usr/bin/env bash

cw_cmd_merge() {
    local base_ref="" fetch=true apply=false
    local -a positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--base) base_ref="${2:?missing value for $1}"; shift 2 ;;
            --no-fetch) fetch=false; shift ;;
            -y|--yes) apply=true; shift ;;
            -h|--help) cw_usage_command merge; return 0 ;;
            --) shift; positional+=("$@"); break ;;
            -*) cw_die "unknown option: $1" ;;
            *) positional+=("$1"); shift ;;
        esac
    done
    set -- "${positional[@]}"
    [ $# -ge 1 ] || { cw_usage_command merge >&2; return 1; }
    [ $# -le 2 ] || cw_die "too many positional arguments"

    local repo_path selector resolved_base base_check_ref base_branch current_branch tmux_target
    repo_path="$(cw_resolve_repo_or_die "$1")"
    selector="${2:-}"
    cw_resolve_selected_worktree "$repo_path" "$selector"
    [ "$CW_SELECTED_WORKTREE_PATH" != "$repo_path" ] || cw_die "merge target must be a secondary worktree"
    [ -n "$CW_SELECTED_WORKTREE_BRANCH" ] || cw_die "cannot merge a detached worktree"
    [ "$fetch" = true ] && cw_fetch_origin "$repo_path"
    resolved_base="$(cw_resolve_base_ref "$repo_path" "$base_ref")"
    base_check_ref="$(cw_preferred_base_ref "$repo_path" "$resolved_base")"
    base_branch="${base_check_ref#origin/}"
    [ "$CW_SELECTED_WORKTREE_BRANCH" != "$base_branch" ] || cw_die "refusing to merge base branch into itself"
    cw_worktree_is_dirty "$CW_SELECTED_WORKTREE_PATH" && cw_die "worktree is dirty: $CW_SELECTED_WORKTREE_PATH"
    cw_worktree_is_dirty "$repo_path" && cw_die "main repo worktree is dirty: $repo_path"
    current_branch="$(git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    [ "$current_branch" = "$base_branch" ] || cw_die "main repo worktree must be on '${base_branch}'"
    if cw_branch_is_merged_into "$repo_path" "$CW_SELECTED_WORKTREE_BRANCH" "$base_check_ref"; then
        printf "%s is already merged into %s\n" "$CW_SELECTED_WORKTREE_BRANCH" "$base_branch"
        return 0
    fi

    tmux_target="$(command -v tmux >/dev/null 2>&1 && cw_tmux_target_for_path "$CW_SELECTED_WORKTREE_PATH" || true)"
    printf "Merge:   %s -> %s\n" "$CW_SELECTED_WORKTREE_BRANCH" "$base_branch"
    printf "Repo:    %s\n" "$repo_path"
    printf "Path:    %s\n" "$CW_SELECTED_WORKTREE_PATH"
    [ -n "$tmux_target" ] && printf "Tmux:    %s\n" "$tmux_target"
    [ "$apply" = true ] || {
        printf "\nDry-run. Re-run with --yes to merge.\n"
        return 0
    }

    [ "$resolved_base" = "$base_branch" ] || git -C "$repo_path" merge --ff-only "$resolved_base"
    if ! git -C "$repo_path" merge --no-ff --no-edit "$CW_SELECTED_WORKTREE_BRANCH"; then
        git -C "$repo_path" merge --abort >/dev/null 2>&1 || true
        cw_die "merge conflicted: ${CW_SELECTED_WORKTREE_BRANCH} -> ${base_branch}"
    fi
    printf "\nMerged %s into %s\n" "$CW_SELECTED_WORKTREE_BRANCH" "$base_branch"
}

cw_cmd_rm() {
    local force_remove=false apply=false tmux_clean=true
    local -a positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force) force_remove=true; shift ;;
            --no-tmux) tmux_clean=false; shift ;;
            -y|--yes) apply=true; shift ;;
            -h|--help) cw_usage_command rm; return 0 ;;
            --) shift; positional+=("$@"); break ;;
            -*) cw_die "unknown option: $1" ;;
            *) positional+=("$1"); shift ;;
        esac
    done
    set -- "${positional[@]}"
    [ $# -ge 1 ] || { cw_usage_command rm >&2; return 1; }
    [ $# -le 2 ] || cw_die "too many positional arguments"

    local repo_path selector base_ref base_check_ref merged="no" dirty="no" tmux_target=""
    repo_path="$(cw_resolve_repo_or_die "$1")"
    selector="${2:-}"
    cw_resolve_selected_worktree "$repo_path" "$selector"
    [ "$CW_SELECTED_WORKTREE_PATH" != "$repo_path" ] || cw_die "refusing to remove the main repo worktree"
    [ -n "$CW_SELECTED_WORKTREE_BRANCH" ] || cw_die "cannot remove a detached worktree with cw rm"
    cw_worktree_is_dirty "$CW_SELECTED_WORKTREE_PATH" && dirty="yes"
    base_ref="$(cw_resolve_base_ref "$repo_path" "")"
    base_check_ref="$(cw_preferred_base_ref "$repo_path" "$base_ref")"
    cw_branch_is_merged_into "$repo_path" "$CW_SELECTED_WORKTREE_BRANCH" "$base_check_ref" && merged="yes"
    tmux_target="$(command -v tmux >/dev/null 2>&1 && cw_tmux_target_for_path "$CW_SELECTED_WORKTREE_PATH" || true)"

    printf "Remove:  %s\n" "$CW_SELECTED_WORKTREE_BRANCH"
    printf "Path:    %s\n" "$CW_SELECTED_WORKTREE_PATH"
    printf "Dirty:   %s\n" "$dirty"
    printf "Merged:  %s\n" "$merged"
    [ -n "$tmux_target" ] && printf "Tmux:    %s\n" "$tmux_target"
    if [ "$apply" = false ]; then
        printf "\nDry-run. Re-run with --yes to remove.\n"
        return 0
    fi

    [ "$dirty" = "no" ] || [ "$force_remove" = true ] || cw_die "worktree is dirty; re-run with --force"
    [ -z "$tmux_target" ] || [ "$tmux_clean" = true ] || cw_die "tmux target exists; re-run without --no-tmux or close it first"
    [ "$tmux_clean" = true ] && cw_close_tmux_windows_for_path "$CW_SELECTED_WORKTREE_PATH"
    if [ "$force_remove" = true ]; then
        git -C "$repo_path" worktree remove "$CW_SELECTED_WORKTREE_PATH" --force
    else
        git -C "$repo_path" worktree remove "$CW_SELECTED_WORKTREE_PATH"
    fi
    if [ "$merged" = "yes" ] && cw_local_branch_exists "$repo_path" "$CW_SELECTED_WORKTREE_BRANCH"; then
        git -C "$repo_path" branch -d "$CW_SELECTED_WORKTREE_BRANCH" >/dev/null 2>&1 || cw_warn "could not delete local branch '${CW_SELECTED_WORKTREE_BRANCH}'"
    fi
    printf "\nRemoved %s\n" "$CW_SELECTED_WORKTREE_BRANCH"
}

cw_cmd_pick() {
    [ $# -eq 1 ] || { cw_usage_command pick >&2; return 1; }
    command -v fzf >/dev/null 2>&1 || cw_die "fzf not found"

    local repo_path repo_name selected selected_path selected_branch picker branch_name
    repo_path="$(cw_resolve_repo_or_die "$1")"
    repo_name="$(basename "$repo_path")"
    picker="fzf"
    [ -n "${TMUX:-}" ] && command -v fzf-tmux >/dev/null 2>&1 && picker="fzf-tmux -p 80%,60%"
    selected="$(cw_worktree_records "$repo_path" | awk -F '\t' '{printf "%s\t%s\n", ($2 == "" ? "-" : $2), $1}' | eval "$picker")"
    [ -n "$selected" ] || return 0
    IFS=$'\t' read -r selected_branch selected_path <<<"$selected"
    branch_name=""
    [ "$selected_branch" != "-" ] && branch_name="$selected_branch"
    cw_open_worktree "$repo_path" "$selected_path" "$branch_name" "$(cw_tmux_name "$repo_name")" "$(cw_default_window_name "$branch_name" "$selected_path")" "none" false false
}
