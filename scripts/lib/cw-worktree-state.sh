#!/usr/bin/env bash

cw_worktree_records() {
    local repo_path="$1"
    local current_path=""
    local current_branch=""
    local current_prunable="no"
    local line=""

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            worktree\ *) current_path="${line#worktree }" ;;
            branch\ refs/heads/*) current_branch="${line#branch refs/heads/}" ;;
            prunable\ *) current_prunable="yes" ;;
            "")
                [ -n "$current_path" ] && printf "%s\t%s\t%s\n" "$current_path" "$current_branch" "$current_prunable"
                current_path=""
                current_branch=""
                current_prunable="no"
                ;;
        esac
    done < <(git -C "$repo_path" worktree list --porcelain)

    [ -n "$current_path" ] && printf "%s\t%s\t%s\n" "$current_path" "$current_branch" "$current_prunable"
}

cw_worktree_is_dirty() {
    [ -n "$(git -C "$1" status --porcelain 2>/dev/null || true)" ]
}

cw_branch_is_merged_into() {
    local repo_path="$1"
    local branch="$2"
    local base_ref="$3"

    git -C "$repo_path" merge-base --is-ancestor "$branch" "$base_ref" >/dev/null 2>&1
}

cw_registered_worktree_path_for_branch() {
    local repo_path="$1"
    local branch="$2"

    while IFS=$'\t' read -r current_path current_branch current_prunable; do
        [ "$current_branch" = "$branch" ] && {
            printf "%s\n" "$current_path"
            return 0
        }
    done < <(cw_worktree_records "$repo_path")
}

cw_registered_branch_for_worktree_path() {
    local repo_path="$1"
    local target_path=""

    target_path="$(cw_canon_path "$2" 2>/dev/null || printf "%s" "$2")"
    while IFS=$'\t' read -r current_path current_branch current_prunable; do
        [ "$current_path" = "$target_path" ] && {
            printf "%s\n" "$current_branch"
            return 0
        }
    done < <(cw_worktree_records "$repo_path")
}

cw_worktree_is_registered() {
    [ -n "$(cw_registered_branch_for_worktree_path "$1" "$2")" ]
}

cw_resolve_worktree_selection() {
    local repo_path="$1"
    local selector="${2:-}"
    local current_path=""
    local current_branch=""
    local current_prunable=""
    local resolved_selector=""
    local exact_path=""
    local exact_branch_path=""
    local exact_branch_name=""
    local -a basename_paths=()
    local -a basename_branches=()
    local -a suffix_paths=()
    local -a suffix_branches=()

    if [ -z "$selector" ]; then
        current_path="$(cw_canon_path "$PWD" 2>/dev/null || true)"
        if [ -n "$current_path" ] && [ "$current_path" != "$repo_path" ]; then
            current_branch="$(cw_registered_branch_for_worktree_path "$repo_path" "$current_path" || true)"
            [ -n "$current_branch" ] && {
                printf "%s\t%s\n" "$current_path" "$current_branch"
                return 0
            }
        fi
        cw_die "missing worktree selector"
    fi

    [ -d "$selector" ] && resolved_selector="$(cw_canon_path "$selector")"
    while IFS=$'\t' read -r current_path current_branch current_prunable; do
        [ -n "$current_path" ] || continue
        [ -n "$resolved_selector" ] && [ "$current_path" = "$resolved_selector" ] && {
            exact_path="$current_path"
            exact_branch_name="$current_branch"
        }
        [ -n "$current_branch" ] && [ "$current_branch" = "$selector" ] && {
            exact_branch_path="$current_path"
            exact_branch_name="$current_branch"
        }
        [ "$(basename "$current_path")" = "$selector" ] && {
            basename_paths+=("$current_path")
            basename_branches+=("$current_branch")
        }
        case "$current_branch" in
            "$selector"|*/"$selector")
                suffix_paths+=("$current_path")
                suffix_branches+=("$current_branch")
                ;;
        esac
    done < <(cw_worktree_records "$repo_path")

    [ -n "$exact_path" ] && { printf "%s\t%s\n" "$exact_path" "$exact_branch_name"; return 0; }
    [ -n "$exact_branch_path" ] && { printf "%s\t%s\n" "$exact_branch_path" "$exact_branch_name"; return 0; }
    [ "${#basename_paths[@]}" -eq 1 ] && { printf "%s\t%s\n" "${basename_paths[0]}" "${basename_branches[0]}"; return 0; }
    [ "${#suffix_paths[@]}" -eq 1 ] && { printf "%s\t%s\n" "${suffix_paths[0]}" "${suffix_branches[0]}"; return 0; }
    if [ "${#basename_paths[@]}" -gt 1 ] || [ "${#suffix_paths[@]}" -gt 1 ]; then
        cw_die "worktree selector is ambiguous: $selector"
    fi
    cw_die "worktree not found: $selector"
}
