#!/usr/bin/env bash

: "${CW_PROJECT_ROOT:=${PI_PROJECT_ROOT:-$HOME/projects}}"

cw_info() {
    printf "%s\n" "$*"
}

cw_warn() {
    printf "warning: %s\n" "$*" >&2
}

cw_die() {
    printf "error: %s\n" "$*" >&2
    exit 1
}

cw_require_bin() {
    command -v "$1" >/dev/null 2>&1 || cw_die "missing command: $1"
}

cw_slugify() {
    printf "%s" "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

cw_slugify_branch_prefix() {
    printf "%s" "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's@[^a-z0-9/_-]+@-@g; s@/+@/@g; s@(^/+|/+$)@@g; s@-{2,}@-@g'
}

cw_tmux_name() {
    local name

    name="$(cw_slugify "$1")"
    [ -n "$name" ] || name="main"
    printf "%.48s" "$name"
}

cw_canon_path() {
    (
        cd "$1" >/dev/null 2>&1 || exit 1
        pwd -P
    )
}

cw_resolve_path_allow_missing() {
    local raw_path="${1:-.}"
    local parent_dir=""

    if [ -d "$raw_path" ]; then
        cw_canon_path "$raw_path"
        return 0
    fi

    if [[ "$raw_path" = /* ]]; then
        parent_dir="$(dirname "$raw_path")"
    else
        parent_dir="$(dirname "$raw_path")"
        parent_dir="$(cw_canon_path "${parent_dir:-.}")"
    fi

    [ -d "$parent_dir" ] || return 1
    printf "%s/%s\n" "$(cw_canon_path "$parent_dir")" "$(basename "$raw_path")"
}

cw_path_is_within() {
    local child_path="${1%/}"
    local parent_path="${2%/}"

    [ "$child_path" = "$parent_path" ] && return 0

    case "${child_path}/" in
        "${parent_path}/"*) return 0 ;;
        *) return 1 ;;
    esac
}

cw_resolve_repo_path() {
    local candidate="$1"
    local resolved=""

    if [ -d "$candidate" ] && git -C "$candidate" rev-parse --show-toplevel >/dev/null 2>&1; then
        resolved="$(git -C "$candidate" rev-parse --show-toplevel)"
    elif [ -d "${CW_PROJECT_ROOT}/${candidate}" ] && git -C "${CW_PROJECT_ROOT}/${candidate}" rev-parse --show-toplevel >/dev/null 2>&1; then
        resolved="$(git -C "${CW_PROJECT_ROOT}/${candidate}" rev-parse --show-toplevel)"
    fi

    [ -n "$resolved" ] || return 1
    cw_canon_path "$resolved"
}

cw_repo_slug_from_path() {
    cw_slugify "$(basename "$1")"
}

cw_worktree_root_for_repo() {
    local repo_path="$1"
    local repo_slug="${2:-$(cw_repo_slug_from_path "$repo_path")}"
    local anchor_path=""

    anchor_path="$(cw_resolve_path_allow_missing "${CW_WORKTREE_ROOT:-$PWD}")" || return 1

    if cw_path_is_within "$anchor_path" "$repo_path"; then
        printf "%s/.worktrees\n" "$repo_path"
    else
        printf "%s/.worktrees/%s\n" "$anchor_path" "$repo_slug"
    fi
}

cw_fetch_origin() {
    local repo_path="$1"

    if git -C "$repo_path" remote get-url origin >/dev/null 2>&1; then
        git -C "$repo_path" fetch origin --prune
    fi
}

cw_default_branch() {
    local repo_path="$1"
    local branch=""
    local candidate

    branch="$(git -C "$repo_path" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
    if [ -n "$branch" ]; then
        printf "%s\n" "$branch"
        return 0
    fi

    for candidate in main master trunk develop; do
        if git -C "$repo_path" show-ref --verify --quiet "refs/heads/${candidate}" \
            || git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/${candidate}"; then
            printf "%s\n" "$candidate"
            return 0
        fi
    done

    branch="$(git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    printf "%s\n" "${branch:-main}"
}

cw_ref_exists() {
    local repo_path="$1"
    local ref="$2"

    git -C "$repo_path" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null 2>&1
}

cw_local_branch_exists() {
    local repo_path="$1"
    local branch="$2"

    git -C "$repo_path" show-ref --verify --quiet "refs/heads/${branch}"
}

cw_remote_branch_exists() {
    local repo_path="$1"
    local branch="$2"

    git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/${branch}"
}

cw_resolve_base_ref() {
    local repo_path="$1"
    local requested="${2:-}"
    local default_branch

    if [ -n "$requested" ]; then
        if cw_ref_exists "$repo_path" "$requested"; then
            printf "%s\n" "$requested"
            return 0
        fi
        if cw_ref_exists "$repo_path" "origin/${requested}"; then
            printf "origin/%s\n" "$requested"
            return 0
        fi
        cw_die "base ref not found: $requested"
    fi

    default_branch="$(cw_default_branch "$repo_path")"
    if cw_ref_exists "$repo_path" "origin/${default_branch}"; then
        printf "origin/%s\n" "$default_branch"
    else
        printf "%s\n" "$default_branch"
    fi
}

cw_preferred_base_ref() {
    local repo_path="$1"
    local resolved_base="$2"
    local local_branch="${resolved_base#origin/}"

    if [ "$local_branch" != "$resolved_base" ] && cw_ref_exists "$repo_path" "$local_branch"; then
        printf "%s\n" "$local_branch"
    else
        printf "%s\n" "$resolved_base"
    fi
}
