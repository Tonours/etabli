#!/usr/bin/env bash

cw_cmd_new() {
    local agent_name="${CW_DEFAULT_AGENT:-pi}" base_ref="" branch_prefix="" detach=false fetch=true print_path=false session_name="" window_name=""
    local -a positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--agent) agent_name="${2:?missing value for $1}"; shift 2 ;;
            -b|--base) base_ref="${2:?missing value for $1}"; shift 2 ;;
            -d|--detach) detach=true; shift ;;
            -n|--no-agent) agent_name="none"; shift ;;
            --no-fetch) fetch=false; shift ;;
            -p|--prefix) branch_prefix="${2:?missing value for $1}"; shift 2 ;;
            -P|--print-path) print_path=true; shift ;;
            -s|--session) session_name="${2:?missing value for $1}"; shift 2 ;;
            -w|--window) window_name="${2:?missing value for $1}"; shift 2 ;;
            -h|--help) cw_usage_command new; return 0 ;;
            --) shift; positional+=("$@"); break ;;
            -*) cw_die "unknown option: $1" ;;
            *) positional+=("$1"); shift ;;
        esac
    done
    set -- "${positional[@]}"
    [ $# -ge 2 ] || { cw_usage_command new >&2; return 1; }
    [ $# -le 3 ] || cw_die "too many positional arguments"

    local repo_path repo_name repo_slug task_slug prefix_norm branch_name worktree_dir worktree_path registered_path current_branch base_resolved
    repo_path="$(cw_resolve_repo_or_die "$1")"
    repo_name="$(basename "$repo_path")"
    repo_slug="$(cw_repo_slug_from_path "$repo_path")"
    task_slug="$(cw_slugify "$2")"
    [ -n "$task_slug" ] || cw_die "task name produced an empty slug"
    prefix_norm="$(cw_slugify_branch_prefix "${branch_prefix:-${3:-feature}}")"
    [ -n "$prefix_norm" ] || cw_die "branch prefix produced an empty value"
    branch_name="${prefix_norm}/${task_slug}"
    worktree_dir="$(cw_worktree_root_for_repo "$repo_path" "$repo_slug" || true)"
    [ -n "$worktree_dir" ] || cw_die "could not resolve worktree root from ${CW_WORKTREE_ROOT:-$PWD}"
    worktree_path="${worktree_dir}/${prefix_norm//\//-}-${task_slug}"
    [ "$fetch" = true ] && cw_fetch_origin "$repo_path"
    registered_path="$(cw_registered_worktree_path_for_branch "$repo_path" "$branch_name" || true)"
    [ -n "$registered_path" ] && worktree_path="$registered_path"
    mkdir -p "$(dirname "$worktree_path")"
    [ -e "$worktree_path" ] && ! cw_worktree_is_registered "$repo_path" "$worktree_path" && cw_die "path exists but is not a registered worktree: $worktree_path"
    current_branch="$(cw_registered_branch_for_worktree_path "$repo_path" "$worktree_path" || true)"
    [ -n "$current_branch" ] && [ "$current_branch" != "$branch_name" ] && cw_die "worktree path already belongs to branch '${current_branch}': $worktree_path"

    if [ -n "$registered_path" ] || [ -d "$worktree_path" ]; then
        cw_info "Reusing worktree: ${worktree_path}"
    else
        base_resolved="$(cw_resolve_base_ref "$repo_path" "$base_ref")"
        cw_info "Creating worktree: ${worktree_path}"
        cw_info "Branch: ${branch_name} (base: ${base_resolved})"
        if cw_local_branch_exists "$repo_path" "$branch_name"; then
            git -C "$repo_path" worktree add "$worktree_path" "$branch_name"
        elif cw_remote_branch_exists "$repo_path" "$branch_name"; then
            git -C "$repo_path" worktree add -b "$branch_name" "$worktree_path" "origin/${branch_name}"
        else
            git -C "$repo_path" worktree add -b "$branch_name" "$worktree_path" "$base_resolved"
        fi
    fi

    worktree_path="$(cw_canon_path "$worktree_path")"
    session_name="${session_name:-$(cw_tmux_name "$repo_name")}"
    window_name="${window_name:-$(cw_default_window_name "$branch_name" "$worktree_path")}"
    cw_open_worktree "$repo_path" "$worktree_path" "$branch_name" "$session_name" "$window_name" "$agent_name" "$detach" "$print_path"
}

cw_cmd_open() {
    local agent_name="none" detach=false print_path=false session_name="" window_name="" selector=""
    local -a positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--agent) agent_name="${2:?missing value for $1}"; shift 2 ;;
            -d|--detach) detach=true; shift ;;
            -n|--no-agent) agent_name="none"; shift ;;
            -P|--print-path) print_path=true; shift ;;
            -s|--session) session_name="${2:?missing value for $1}"; shift 2 ;;
            -w|--window) window_name="${2:?missing value for $1}"; shift 2 ;;
            -h|--help) cw_usage_command open; return 0 ;;
            --) shift; positional+=("$@"); break ;;
            -*) cw_die "unknown option: $1" ;;
            *) positional+=("$1"); shift ;;
        esac
    done
    set -- "${positional[@]}"
    [ $# -ge 1 ] || { cw_usage_command open >&2; return 1; }
    [ $# -le 2 ] || cw_die "too many positional arguments"

    local repo_path repo_name selector
    repo_path="$(cw_resolve_repo_or_die "$1")"
    repo_name="$(basename "$repo_path")"
    selector="${2:-}"
    cw_resolve_selected_worktree "$repo_path" "$selector"
    session_name="${session_name:-$(cw_tmux_name "$repo_name")}"
    window_name="${window_name:-$(cw_default_window_name "$CW_SELECTED_WORKTREE_BRANCH" "$CW_SELECTED_WORKTREE_PATH")}"
    cw_open_worktree "$repo_path" "$CW_SELECTED_WORKTREE_PATH" "$CW_SELECTED_WORKTREE_BRANCH" "$session_name" "$window_name" "$agent_name" "$detach" "$print_path"
}

cw_cmd_ls() {
    [ $# -eq 1 ] || { cw_usage_command ls >&2; return 1; }
    local repo_path current_path current_branch current_prunable state dirty tmux_target
    repo_path="$(cw_resolve_repo_or_die "$1")"
    printf "Repository: %s\n\n" "$repo_path"
    printf "%-10s %-8s %-18s %s\n" "state" "dirty" "tmux" "branch -> path"
    printf "%-10s %-8s %-18s %s\n" "----------" "--------" "------------------" "-------------"
    while IFS=$'\t' read -r current_path current_branch current_prunable; do
        [ -n "$current_path" ] || continue
        state="worktree"
        [ "$current_path" = "$repo_path" ] && state="main"
        [ "$current_prunable" = "yes" ] && state="stale"
        dirty="n/a"
        [ -d "$current_path" ] && dirty="no" && cw_worktree_is_dirty "$current_path" && dirty="yes"
        tmux_target="-"
        if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
            tmux_target="$(cw_tmux_target_for_path "$current_path" || true)"
            [ -n "$tmux_target" ] || tmux_target="-"
        fi
        printf "%-10s %-8s %-18s %s -> %s\n" "$state" "$dirty" "$tmux_target" "${current_branch:--}" "$current_path"
    done < <(cw_worktree_records "$repo_path")
}

cw_cmd_attach() {
    [ $# -ge 1 ] || { cw_usage_command attach >&2; return 1; }
    [ $# -le 2 ] || cw_die "too many positional arguments"
    command -v tmux >/dev/null 2>&1 || cw_die "tmux not found"

    local repo_path tmux_target
    repo_path="$(cw_resolve_repo_or_die "$1")"
    cw_resolve_selected_worktree "$repo_path" "${2:-}"
    tmux_target="$(cw_tmux_target_for_path "$CW_SELECTED_WORKTREE_PATH" || true)"
    [ -n "$tmux_target" ] || cw_die "no tmux target found for ${CW_SELECTED_WORKTREE_PATH}; use 'cw open' first"
    cw_attach_tmux_target "$tmux_target"
}
