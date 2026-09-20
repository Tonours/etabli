#!/usr/bin/env bash

# Shared reconciliation primitives for Etabli-managed local surfaces.
# Callers select a mode; this module owns path classification and mutation.

managed_surface_emit() {
  local status="$1"
  local message="$2"

  if declare -F managed_surface_status >/dev/null 2>&1; then
    managed_surface_status "$status" "$message"
  else
    printf '%-14s %s\n' "$status" "$message"
  fi
}

managed_surface_backup_path() {
  local path="$1"
  local timestamp="$2"
  local candidate="${path}.bak.${timestamp}"
  local index=1

  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="${path}.bak.${timestamp}.${index}"
    index=$((index + 1))
  done

  printf '%s\n' "$candidate"
}

managed_surface_same_link() {
  local source_path="$1"
  local destination_path="$2"

  [ -L "$destination_path" ] && [ "$(readlink "$destination_path")" = "$source_path" ] && [ -e "$destination_path" ]
}

managed_surface_reconcile_link() {
  local mode="$1"
  local source_path="$2"
  local destination_path="$3"
  local label="$4"
  local current=""
  local backup

  if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
    case "$mode" in
    deploy | install)
      managed_surface_emit MISSING "$label source missing: $source_path"
      return 1
      ;;
    check)
      ISSUES=$((ISSUES + 1))
      UNRESOLVED=$((UNRESOLVED + 1))
      managed_surface_emit WARN "$label source missing (expected $source_path)"
      return 0
      ;;
    esac
  fi

  if managed_surface_same_link "$source_path" "$destination_path"; then
    case "$mode" in
    deploy | install) managed_surface_emit OK "$label" ;;
    check)
      if [ "${VERBOSE:-0}" -eq 1 ]; then
        managed_surface_emit OK "$label -> $source_path"
      fi
      ;;
    esac
    return 0
  fi

  case "$mode" in
  deploy | install)
    if [ "${DRY_RUN:-1}" -eq 1 ]; then
      if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
        managed_surface_emit WOULD_BACKUP "$destination_path"
      fi
      managed_surface_emit WOULD_LINK "$label -> $source_path"
      return 0
    fi

    mkdir -p "$(dirname "$destination_path")"
    if [ -e "$destination_path" ] || [ -L "$destination_path" ]; then
      if [ "$mode" = install ] && [ -L "$destination_path" ]; then
        rm -f "$destination_path"
      else
        backup="$(managed_surface_backup_path "$destination_path" "$TIMESTAMP")"
        mv "$destination_path" "$backup"
        managed_surface_emit BACKUP "$backup"
      fi
    fi
    ln -s "$source_path" "$destination_path"
    managed_surface_emit LINK "$label"
    ;;
  check)
    if [ -L "$destination_path" ]; then
      current="$(readlink "$destination_path")"
      managed_surface_emit WARN "$label -> ${current:-<unknown>} (expected $source_path)"
    elif [ -e "$destination_path" ]; then
      managed_surface_emit WARN "$label exists but is not a symlink (expected $source_path)"
    else
      managed_surface_emit WARN "$label missing (expected $source_path)"
    fi
    ISSUES=$((ISSUES + 1))

    if [ "${FIX:-0}" -eq 1 ]; then
      mkdir -p "$(dirname "$destination_path")"
      if [ -e "$destination_path" ] && [ ! -L "$destination_path" ]; then
        backup="$(managed_surface_backup_path "$destination_path" "$TIMESTAMP")"
        mv "$destination_path" "$backup"
        managed_surface_emit BACKUP "$label moved to $backup"
      else
        rm -rf "$destination_path"
      fi
      ln -sfn "$source_path" "$destination_path"
      FIXED=$((FIXED + 1))
      managed_surface_emit FIXED "$label -> $source_path"
    fi
    ;;
  *)
    printf 'managed_surface_reconcile_link: unsupported mode %s\n' "$mode" >&2
    return 2
    ;;
  esac
}

managed_surface_remove_exact_link() {
  local mode="$1"
  local target_path="$2"
  local label="$3"
  local link_target expected_target

  shift 3
  if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
    [ "$mode" = deploy ] && managed_surface_emit OK "$label absent"
    return 0
  fi
  if [ ! -L "$target_path" ]; then
    [ "$mode" = deploy ] && managed_surface_emit KEEP "$label unmanaged"
    return 0
  fi

  link_target="$(readlink "$target_path")"
  for expected_target in "$@"; do
    [ "$link_target" = "$expected_target" ] || continue
    if [ "$mode" = deploy ] && [ "${DRY_RUN:-1}" -eq 1 ]; then
      managed_surface_emit WOULD_REMOVE "$label"
    else
      rm -f "$target_path"
      if [ "$mode" = deploy ]; then
        managed_surface_emit REMOVE "$label"
      else
        managed_surface_emit FIXED "removed $label"
      fi
    fi
    return 0
  done

  if [ "$mode" = deploy ]; then
    managed_surface_emit KEEP "$label unmanaged"
  fi
  return 0
}

managed_surface_prune_stale_claude_agents() {
  local mode="$1"
  local repo_dir="$2"
  local home_dir="$3"
  local installed_dir="$home_dir/.claude/agents"
  local agent_link agent_target

  [ -d "$installed_dir" ] || return 0

  for agent_link in "$installed_dir"/*.md; do
    [ -L "$agent_link" ] || continue
    agent_target="$(readlink "$agent_link")"
    case "$agent_target" in
    "$repo_dir/claude/agents/"* | "$repo_dir/claude/scopes/"*/agents/*) ;;
    *) continue ;;
    esac
    [ -e "$agent_target" ] && continue

    case "$mode" in
    deploy)
      if [ "${DRY_RUN:-1}" -eq 1 ]; then
        managed_surface_emit WOULD_REMOVE "stale managed Claude agent $(basename "$agent_link")"
      else
        rm -f "$agent_link"
        managed_surface_emit REMOVE "stale managed Claude agent $(basename "$agent_link")"
      fi
      ;;
    check)
      ISSUES=$((ISSUES + 1))
      managed_surface_emit WARN "stale managed Claude agent $(basename "$agent_link") -> $agent_target"
      if [ "${FIX:-0}" -eq 1 ]; then
        rm -f "$agent_link"
        FIXED=$((FIXED + 1))
        managed_surface_emit FIXED "removed stale managed Claude agent $(basename "$agent_link")"
      fi
      ;;
    install)
      rm -f "$agent_link"
      managed_surface_emit FIXED "removed stale managed Claude agent '$(basename "$agent_link")'"
      ;;
    esac
  done
}

managed_surface_skill_roots() {
  local repo_dir="$1"
  local candidate resolved group_dir

  while IFS= read -r candidate; do
    resolved="$(cd "$candidate" >/dev/null 2>&1 && pwd -P)" || continue
    printf '%s\n' "$resolved"
  done < <(
    printf '%s/pi/skills\n' "$repo_dir"
    find "$repo_dir/vendor" "$repo_dir/claude/scopes" \
      -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
      while IFS= read -r group_dir; do
        printf '%s/skills\n' "$group_dir"
      done
  )
}

managed_surface_skill_target_is_managed() {
  local repo_dir="$1"
  local managed_roots="$2"
  local skill_target="$3"
  local skill_parent

  skill_parent="$(cd "$(dirname "$skill_target")" >/dev/null 2>&1 && pwd -P)"
  if [ -n "$skill_parent" ]; then
    printf '%s\n' "$managed_roots" | grep -qxF "$skill_parent"
    return
  fi

  case "$skill_target" in
  "$repo_dir/pi/skills/"?* | "$repo_dir/vendor/"?*"/skills/"?* | "$repo_dir/claude/scopes/"?*"/skills/"?*) return 0 ;;
  esac
  return 1
}

managed_surface_prune_stale_skill_links() {
  local mode="$1"
  local repo_dir="$2"
  local home_dir="$3"
  local managed_roots surface skill_link skill_target

  managed_roots="$(managed_surface_skill_roots "$repo_dir")"
  for surface in \
    "$home_dir/.claude/skills" \
    "$home_dir/.pi/agent/skills" \
    "$home_dir/.codex/skills" \
    "$home_dir/.config/devin/skills" \
    "$home_dir/.agents/skills"; do
    [ -d "$surface" ] || continue
    while IFS= read -r skill_link; do
      [ -n "$skill_link" ] || continue
      skill_target="$(readlink "$skill_link")"
      if [ "${skill_target#/}" = "$skill_target" ]; then
        skill_target="$(dirname "$skill_link")/$skill_target"
      fi
      managed_surface_skill_target_is_managed "$repo_dir" "$managed_roots" "$skill_target" || continue
      [ -e "$skill_target" ] && continue

      case "$mode" in
      deploy)
        if [ "${DRY_RUN:-1}" -eq 1 ]; then
          managed_surface_emit WOULD_REMOVE "stale managed skill $(basename "$skill_link") from $surface"
        else
          rm -f "$skill_link"
          managed_surface_emit REMOVE "stale managed skill $(basename "$skill_link") from $surface"
        fi
        ;;
      install)
        rm -f "$skill_link"
        managed_surface_emit FIXED "removed stale managed skill '$(basename "$skill_link")' from $surface"
        ;;
      esac
    done < <(find "$surface" -mindepth 1 -maxdepth 1 -type l | sort)
  done
}

managed_surface_catalog_contains() {
  local candidate="$1"
  shift
  local entry

  [ -n "$candidate" ] || return 1
  for entry in "$@"; do
    [ -n "$entry" ] || continue
    [ "$candidate" = "$entry" ] && return 0
  done
  return 1
}

managed_surface_prune_link() {
  local mode="$1"
  local path="$2"
  local label="$3"

  case "$mode" in
  deploy)
    if [ "${DRY_RUN:-1}" -eq 1 ]; then
      managed_surface_emit WOULD_REMOVE "$label"
    else
      rm -f "$path"
      managed_surface_emit REMOVE "$label"
    fi
    ;;
  check)
    ISSUES=$((ISSUES + 1))
    managed_surface_emit WARN "$label"
    if [ "${FIX:-0}" -eq 1 ]; then
      rm -f "$path"
      FIXED=$((FIXED + 1))
      managed_surface_emit FIXED "$label"
    fi
    ;;
  esac
}

managed_surface_prune_pi_cross_surface_links() {
  local mode="$1"
  local repo_dir="$2"
  local home_dir="$3"
  local surface skill_link

  for surface in .claude/skills .codex/skills .config/devin/skills; do
    [ -d "$home_dir/$surface" ] || continue
    for skill_link in "$home_dir/$surface"/*; do
      [ -L "$skill_link" ] || continue
      case "$(readlink "$skill_link")" in
      "$repo_dir/pi/skills/"*)
        managed_surface_prune_link "$mode" "$skill_link" "Pi-sourced skill link $(basename "$skill_link") on $surface"
        ;;
      esac
    done
  done
}

managed_surface_prune_unlisted_source_skills() {
  local mode="$1"
  local repo_dir="$2"
  local home_dir="$3"
  local surface="$4"
  local label="$5"
  local source_policy="$6"
  shift 6
  local skill_link skill_target skill_name

  [ -d "$home_dir/$surface" ] || return 0
  for skill_link in "$home_dir/$surface"/*; do
    [ -L "$skill_link" ] || continue
    skill_target="$(readlink "$skill_link")"
    if [ "$source_policy" = pi ]; then
      case "$skill_target" in "$repo_dir/pi/skills/"*) ;; *) continue ;; esac
    else
      case "$skill_target" in "$repo_dir/pi/skills/"* | "$repo_dir/vendor/"*) ;; *) continue ;; esac
    fi
    skill_name="$(basename "$skill_link")"
    if ! managed_surface_catalog_contains "$skill_name" "$@"; then
      managed_surface_prune_link "$mode" "$skill_link" "demoted $label skill $skill_name remains in $surface"
    fi
  done
}

managed_surface_prune_vendor_skill_links() {
  local mode="$1"
  local repo_dir="$2"
  local home_dir="$3"
  local catalog="$4"
  local active_scopes="$5"
  local surface skill_link skill_target link_name
  local record_scope record_name record_pi_core record_vendor matched

  for surface in .pi/agent/skills .claude/skills .codex/skills .config/devin/skills .agents/skills; do
    [ -d "$home_dir/$surface" ] || continue
    for skill_link in "$home_dir/$surface"/*; do
      [ -L "$skill_link" ] || continue
      skill_target="$(readlink "$skill_link")"
      link_name="$(basename "$skill_link")"
      case "$skill_target" in
      */.agents/skills/* | */.claude/skills/* | */.codex/* | */.config/devin/*)
        if [ ! -e "$skill_link" ]; then
          managed_surface_prune_link "$mode" "$skill_link" "broken cross-surface mirror $link_name from $surface"
          continue
        fi
        ;;
      esac
      matched=""
      while IFS=$'\t' read -r record_scope record_name _record_dir record_pi_core record_vendor; do
        [ "$record_name" = "$link_name" ] || continue
        case "$skill_target" in
        *"/$record_vendor/skills/"*) ;;
        *) continue ;;
        esac
        matched=1
        if ! vendor_surface_expected "$surface" "$record_scope" "$record_pi_core" "$active_scopes"; then
          managed_surface_prune_link "$mode" "$skill_link" "vendor skill $link_name not expected in $surface"
        fi
        break
      done < <(skill_catalog_vendor_records "$catalog" "$repo_dir")
      if [ -z "$matched" ]; then
        case "$skill_target" in
        "$repo_dir"/vendor/*/skills/*)
          managed_surface_prune_link "$mode" "$skill_link" "orphan vendor skill $link_name from $surface"
          ;;
        esac
      fi
    done
  done
}

managed_surface_skill_is_shadowed() {
  local skill_name="$1"
  local active_scopes="$2"
  local entry owning_scope

  # A machine-scoped source owns these names instead of the shared Claude skill.
  for entry in work:adr; do
    owning_scope="${entry%%:*}"
    [ "${entry#*:}" = "$skill_name" ] || continue
    case " $active_scopes " in
    *" $owning_scope "*) return 0 ;;
    esac
  done
  return 1
}

managed_surface_remove_symlink() {
  local mode="$1"
  local target_path="$2"
  local label="$3"

  [ -L "$target_path" ] || return 0
  if [ "$mode" = deploy ] && [ "${DRY_RUN:-1}" -eq 1 ]; then
    managed_surface_emit WOULD_REMOVE "$label"
    return 0
  fi
  rm -f "$target_path"
  managed_surface_emit REMOVE "$label"
}
