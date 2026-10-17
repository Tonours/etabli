#!/usr/bin/env bash

skill_catalog_names() {
  local catalog="$1"
  local source="${2:-any}"
  local flag="${3:-any}"

  awk -F '\t' -v source="$source" -v flag="$flag" '
    $0 !~ /^#/ && NF >= 4 &&
    (source == "any" || $2 == source) &&
    (flag == "any" || (flag == "pi_core" && $3 == "1") || (flag == "locked" && $4 == "1")) {
      print $1
    }
  ' "$catalog"
}

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

skill_catalog_vendor_records() {
  local catalog="$1"
  local repo_dir="$2"
  local vendor _vendor_repo _vendor_ref vendor_scope _vendor_skills
  local catalog_name catalog_pi_core skill_dir skill_name

  # shellcheck disable=SC2034
  while IFS=$'\t' read -r vendor _vendor_repo _vendor_ref vendor_scope _vendor_skills || [ -n "$vendor" ]; do
    case "$vendor" in '' | \#*) continue ;; esac

    while IFS=$'\t' read -r catalog_name catalog_pi_core; do
      [ -n "$catalog_name" ] || continue
      skill_dir="$repo_dir/vendor/$vendor/skills/$catalog_name"
      skill_name="$(skill_declared_name "$skill_dir")"
      printf '%s\t%s\t%s\t%s\t%s\n' "$vendor_scope" "$skill_name" "$skill_dir" "$catalog_pi_core" "$vendor"
    done < <(awk -F '\t' -v vendor="$vendor" '$0 !~ /^#/ && NF >= 4 && $2 == vendor { print $1 "\t" $3 }' "$catalog")
  done <"$repo_dir/vendor/sources.tsv"
}

