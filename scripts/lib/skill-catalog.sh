#!/usr/bin/env bash

skill_declared_name() {
  local skill_dir="$1"
  local declared

  declared="$(awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    /^name:[[:space:]]/ {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$skill_dir/SKILL.md" 2>/dev/null)"

  # Link names must be valid skill slugs; a display-case declaration
  # (e.g. "Poteto Mode") falls back to the directory basename; skill
  # directories are lowercase-hyphen only.
  if [ -n "$declared" ] && printf '%s' "$declared" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
    printf '%s\n' "$declared"
  else
    basename "$skill_dir"
  fi
}

# One record per deployable catalog row, tab-separated:
#   scope  link-name  skill-dir  pi_core  source
# First-party rows (source etabli) take their scope from the first segment of
# skills/<scope>/<skill>; vendor rows from vendor/sources.tsv. Shelf rows
# (source extras) are never deployed and emit nothing.
skill_catalog_records() {
  local catalog="$1"
  local repo_dir="$2"
  local vendor _vendor_repo _vendor_ref vendor_scope _vendor_skills
  local catalog_name catalog_pi_core skill_dir

  while IFS=$'\t' read -r catalog_name catalog_pi_core; do
    [ -n "$catalog_name" ] || continue
    skill_dir="$repo_dir/skills/$catalog_name"
    printf '%s\t%s\t%s\t%s\tetabli\n' "${catalog_name%%/*}" "$(skill_declared_name "$skill_dir")" "$skill_dir" "$catalog_pi_core"
  done < <(awk -F '\t' '$0 !~ /^#/ && NF >= 4 && $2 == "etabli" { print $1 "\t" $3 }' "$catalog")

  # shellcheck disable=SC2034
  while IFS=$'\t' read -r vendor _vendor_repo _vendor_ref vendor_scope _vendor_skills || [ -n "$vendor" ]; do
    case "$vendor" in '' | \#*) continue ;; esac

    while IFS=$'\t' read -r catalog_name catalog_pi_core; do
      [ -n "$catalog_name" ] || continue
      skill_dir="$repo_dir/vendor/$vendor/skills/$catalog_name"
      printf '%s\t%s\t%s\t%s\t%s\n' "$vendor_scope" "$(skill_declared_name "$skill_dir")" "$skill_dir" "$catalog_pi_core" "$vendor"
    done < <(awk -F '\t' -v vendor="$vendor" '$0 !~ /^#/ && NF >= 4 && $2 == vendor { print $1 "\t" $3 }' "$catalog")
  done <"$repo_dir/vendor/sources.tsv"
}

# Which surfaces receive a record: Claude for every active-scope record, Pi
# only when the record is pi_core. Fails closed on a missing scope.
skill_surface_expected() {
  local surface="$1"
  local record_scope="$2"
  local record_pi_core="$3"
  local active_scopes="$4"

  [ -n "$record_scope" ] || return 1
  case " $active_scopes " in
  *" $record_scope "*) ;;
  *) return 1 ;;
  esac
  if [ "$surface" = ".pi/agent/skills" ] && [ "$record_pi_core" != "1" ]; then
    return 1
  fi
  return 0
}
