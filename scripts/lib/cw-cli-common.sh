#!/usr/bin/env bash

cw_usage() {
    cat <<EOF
Usage:
  cw new [options] <repo|path> <task> [branch-prefix]
  cw open [options] <repo|path> [branch|path|name]
  cw ls <repo|path>
  cw attach <repo|path> [branch|path|name]
  cw merge [options] <repo|path> [branch|path|name]
  cw rm [options] <repo|path> [branch|path|name]
  cw pick <repo|path>

Compatibility:
  cw [options] <repo|path> <task> [branch-prefix]   Alias for 'cw new'

Run 'cw <command> --help' for command-specific flags.
EOF
}

cw_usage_command() {
    case "$1" in
        new)
            cat <<EOF
Usage: cw new [options] <repo|path> <task> [branch-prefix]

Options:
  -a, --agent <name>     Agent to launch in a newly created tmux window.
  -b, --base <ref>       Base branch/ref. Default: repo default branch.
  -d, --detach           Do not attach or switch to the tmux target.
  -n, --no-agent         Shortcut for --agent none.
      --no-fetch         Skip 'git fetch origin --prune'.
  -p, --prefix <prefix>  Branch prefix. Overrides the third positional arg.
  -P, --print-path       Print the resolved worktree path.
  -s, --session <name>   Override the tmux session name.
  -w, --window <name>    Override the tmux window name.
EOF
            ;;
        open)
            cat <<EOF
Usage: cw open [options] <repo|path> [branch|path|name]

Open or reuse a tmux target for an existing worktree.
If the selector is omitted, the current directory is used when inside a registered worktree.

Options:
  -a, --agent <name>   Agent to launch only when a new tmux window is created.
  -d, --detach         Do not attach or switch to the tmux target.
  -n, --no-agent       Shortcut for --agent none.
  -P, --print-path     Print the resolved worktree path.
  -s, --session <name> Override the tmux session name.
  -w, --window <name>  Override the tmux window name.
EOF
            ;;
        ls)
            cat <<EOF
Usage: cw ls <repo|path>

List registered worktrees with dirty state and tmux targets.
EOF
            ;;
        attach)
            cat <<EOF
Usage: cw attach <repo|path> [branch|path|name]

Attach to an existing tmux target for a worktree.
EOF
            ;;
        merge)
            cat <<EOF
Usage: cw merge [options] <repo|path> [branch|path|name]

Merge a worktree branch into the base branch from the main repo worktree.
Dry-run by default.

Options:
  -b, --base <ref>   Base branch/ref. Default: repo default branch.
      --no-fetch     Skip 'git fetch origin --prune'.
  -y, --yes          Apply the merge.
EOF
            ;;
        rm)
            cat <<EOF
Usage: cw rm [options] <repo|path> [branch|path|name]

Remove a single worktree. Dry-run by default.

Options:
  -f, --force      Remove dirty worktrees too.
      --no-tmux    Refuse to close tmux windows for the worktree.
  -y, --yes        Apply the removal.
EOF
            ;;
        pick)
            cat <<EOF
Usage: cw pick <repo|path>

Pick a worktree with fzf/fzf-tmux, then open or attach it.
EOF
            ;;
        *)
            cw_usage
            ;;
    esac
}

cw_resolve_agent_command() {
    local agent_name="$1"
    local candidate=""

    case "$agent_name" in
        ""|none) return 1 ;;
        auto)
            for candidate in codex claude pi; do
                command -v "$candidate" >/dev/null 2>&1 && {
                    printf "%s\n" "$candidate"
                    return 0
                }
            done
            return 1
            ;;
        pi|claude|codex)
            command -v "$agent_name" >/dev/null 2>&1 || return 1
            printf "%s\n" "$agent_name"
            ;;
        *)
            printf "%s\n" "$agent_name"
            ;;
    esac
}

cw_resolve_repo_or_die() {
    local repo_path=""

    cw_require_bin git
    repo_path="$(cw_resolve_repo_path "$1" 2>/dev/null || true)"
    [ -n "$repo_path" ] || cw_die "repo not found: $1"
    printf "%s\n" "$repo_path"
}

cw_default_window_name() {
    local branch_name="$1"
    local worktree_path="$2"
    local raw_name="${branch_name//\//-}"

    [ -n "$raw_name" ] || raw_name="$(basename "$worktree_path")"
    cw_tmux_name "$raw_name"
}

cw_attach_tmux_target() {
    local target="$1"
    local session_name="${target%%:*}"

    if [ -n "${TMUX:-}" ]; then
        tmux switch-client -t "$session_name" \; select-window -t "$target"
    else
        tmux select-window -t "$target"
        exec tmux attach-session -t "$session_name"
    fi
}

cw_ensure_tmux_target() {
    local session_name="$1"
    local window_name="$2"
    local worktree_path="$3"
    local target=""
    local created="no"

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        cw_info "Creating tmux session: ${session_name}" >&2
        tmux new-session -d -s "$session_name" -n "$window_name" -c "$worktree_path"
        created="yes"
    fi

    target="$(cw_tmux_target_for_path_in_session "$session_name" "$worktree_path" || true)"
    if [ -z "$target" ]; then
        cw_info "Creating tmux window: ${window_name}" >&2
        target="$(tmux new-window -P -F '#{session_name}:#{window_index}' -t "${session_name}:" -n "$window_name" -c "$worktree_path")"
        created="yes"
    else
        cw_info "Reusing tmux target: ${target}" >&2
    fi

    printf "%s\t%s\n" "$target" "$created"
}

cw_print_summary() {
    local repo_path="$1"
    local worktree_path="$2"
    local branch_name="$3"
    local tmux_target="$4"
    local agent_command="$5"
    local print_path="$6"

    printf "\nrepo:      %s\n" "$repo_path"
    printf "worktree:  %s\n" "$worktree_path"
    printf "branch:    %s\n" "${branch_name:--}"
    [ -n "$tmux_target" ] && printf "tmux:      %s\n" "$tmux_target"
    [ -n "$agent_command" ] && printf "agent:     %s\n" "$agent_command"
    [ "$print_path" = true ] && printf "path:      %s\n" "$worktree_path"
    printf "\n"
}

cw_open_worktree() {
    local repo_path="$1"
    local worktree_path="$2"
    local branch_name="$3"
    local session_name="$4"
    local window_name="$5"
    local agent_name="$6"
    local detach="$7"
    local print_path="$8"
    local target_data=""
    local tmux_target=""
    local created="no"
    local agent_command=""

    if ! command -v tmux >/dev/null 2>&1; then
        cw_warn "tmux not found; worktree ready at ${worktree_path}"
        [ "$print_path" = true ] && printf "%s\n" "$worktree_path"
        return 0
    fi

    target_data="$(cw_ensure_tmux_target "$session_name" "$window_name" "$worktree_path")"
    IFS=$'\t' read -r tmux_target created <<<"$target_data"
    agent_command="$(cw_resolve_agent_command "$agent_name" || true)"

    if [ -n "$agent_command" ] && [ "$created" = "yes" ]; then
        cw_info "Launching agent in ${tmux_target}: ${agent_command}"
        tmux send-keys -t "$tmux_target" "$agent_command" C-m
    elif [ "$agent_name" != "none" ] && [ -n "$agent_name" ] && [ -z "$agent_command" ]; then
        cw_warn "agent '${agent_name}' could not be resolved; skipping launch"
    fi

    cw_print_summary "$repo_path" "$worktree_path" "$branch_name" "$tmux_target" "$agent_command" "$print_path"
    if [ "$detach" = false ]; then
        cw_attach_tmux_target "$tmux_target"
    fi
}

cw_resolve_selected_worktree() {
    local repo_path="$1"
    local selector="${2:-}"
    local resolved=""

    resolved="$(cw_resolve_worktree_selection "$repo_path" "$selector")"
    IFS=$'\t' read -r CW_SELECTED_WORKTREE_PATH CW_SELECTED_WORKTREE_BRANCH <<<"$resolved"
}
