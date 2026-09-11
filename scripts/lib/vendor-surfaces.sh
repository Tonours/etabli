#!/usr/bin/env bash
# Shared vendor-skill surface policy (ADR-0018 surfaces).
# One source of truth for which surfaces receive an active vendor skill:
# Claude, Codex and Devin always, Pi only when the catalog marks the skill
# pi_core; active scope gates every surface. Sourced by install-main.sh,
# deploy-agent-workflow and check-fix-symlinks.sh.

vendor_surface_expected() {
  local surface="$1"
  local record_scope="$2"
  local record_pi_core="$3"
  local active_scopes="$4"

  # Fail closed on a source row missing its scope column.
  if [ -z "$record_scope" ]; then
    return 1
  fi
  case " $active_scopes " in
  *" $record_scope "*) ;;
  *) return 1 ;;
  esac
  if [ "$surface" = ".pi/agent/skills" ] && [ "$record_pi_core" != "1" ]; then
    return 1
  fi
  return 0
}

vendor_link_skill_surfaces() {
  local home_dir="$1"
  local skill_dir="$2"
  local skill_name="$3"
  local pi_core="$4"
  local record_scope="$5"
  local active_scopes="$6"
  local surface

  for surface in .claude/skills .codex/skills .config/devin/skills .pi/agent/skills; do
    if vendor_surface_expected "$surface" "$record_scope" "$pi_core" "$active_scopes"; then
      mkdir -p "$home_dir/$surface"
      ln -sfn "$skill_dir" "$home_dir/$surface/$skill_name"
    fi
  done
}

# Migration helper: remove links this policy no longer expects (e.g. a Pi link
# for a vendor skill relabelled pi_core=0). Only links pointing at this skill's
# source directory are removed, so an unrelated user symlink survives.
vendor_prune_unexpected_skill_surfaces() {
  local home_dir="$1"
  local skill_dir="$2"
  local skill_name="$3"
  local pi_core="$4"
  local record_scope="$5"
  local active_scopes="$6"
  local surface link_path

  for surface in .claude/skills .codex/skills .config/devin/skills .pi/agent/skills; do
    link_path="$home_dir/$surface/$skill_name"
    if ! vendor_surface_expected "$surface" "$record_scope" "$pi_core" "$active_scopes" &&
      [ -L "$link_path" ] &&
      [ "$(readlink "$link_path")" = "$skill_dir" ]; then
      rm -f "$link_path"
    fi
  done
}
