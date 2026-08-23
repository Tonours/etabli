#!/usr/bin/env bash

skill_catalog_names() {
  local catalog="$1"
  local source="${2:-any}"
  local flag="${3:-any}"

  awk -F '\t' -v source="$source" -v flag="$flag" '
    $0 !~ /^#/ && NF >= 5 &&
    (source == "any" || $2 == source) &&
    (flag == "any" || (flag == "pi_core" && $3 == "1") ||
      (flag == "agents_visible" && $4 == "1") || (flag == "locked" && $5 == "1")) {
      print $1
    }
  ' "$catalog"
}

skill_catalog_source_of() {
  local catalog="$1"
  local name="$2"

  awk -F '\t' -v name="$name" '
    $0 !~ /^#/ && NF >= 5 && $1 == name { print $2; exit }
  ' "$catalog"
}

skill_source_root() {
  local repo_dir="$1"
  local source="$2"

  if [ "$source" = "pi" ]; then
    printf '%s/pi/skills\n' "$repo_dir"
    return 0
  fi

  if [ -d "$repo_dir/vendor/$source/skills" ]; then
    printf '%s/vendor/%s/skills\n' "$repo_dir" "$source"
    return 0
  fi

  return 1
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

  if [ -n "$declared" ]; then
    printf '%s\n' "$declared"
  else
    basename "$skill_dir"
  fi
}

skill_vendor_scope() {
  local repo_dir="$1"
  local vendor="$2"

  awk -F '\t' -v vendor="$vendor" '
    $0 !~ /^#/ && NF >= 5 && $1 == vendor { print $4; exit }
  ' "$repo_dir/vendor/sources.tsv"
}

skill_catalog_dir() {
  local catalog="$1"
  local repo_dir="$2"
  local name="$3"
  local source

  source="$(skill_catalog_source_of "$catalog" "$name")"
  [ -n "$source" ] || return 1
  printf '%s/%s\n' "$(skill_source_root "$repo_dir" "$source")" "$name"
}

skill_catalog_vendor_records() {
  local catalog="$1"
  local repo_dir="$2"
  local vendor vendor_repo vendor_ref vendor_scope vendor_skills
  local catalog_name skill_dir skill_name

  while IFS=$'\t' read -r vendor vendor_repo vendor_ref vendor_scope vendor_skills || [ -n "$vendor" ]; do
    case "$vendor" in ''|\#*) continue ;; esac

    while IFS= read -r catalog_name; do
      [ -n "$catalog_name" ] || continue
      skill_dir="$repo_dir/vendor/$vendor/skills/$catalog_name"
      skill_name="$(skill_declared_name "$skill_dir")"
      printf '%s\t%s\t%s\n' "$vendor_scope" "$skill_name" "$skill_dir"
    done < <(skill_catalog_names "$catalog" "$vendor" any)
  done <"$repo_dir/vendor/sources.tsv"
}

skill_catalog_active_vendor_records() {
  local catalog="$1"
  local repo_dir="$2"
  local active_scopes="$3"
  local vendor_scope skill_name skill_dir

  while IFS=$'\t' read -r vendor_scope skill_name skill_dir; do
    case " $active_scopes " in
      *" $vendor_scope "*) printf '%s\t%s\n' "$skill_name" "$skill_dir" ;;
    esac
  done < <(skill_catalog_vendor_records "$catalog" "$repo_dir")
}

skill_catalog_inactive_vendor_records() {
  local catalog="$1"
  local repo_dir="$2"
  local active_scopes="$3"
  local vendor_scope skill_name skill_dir

  while IFS=$'\t' read -r vendor_scope skill_name skill_dir; do
    case " $active_scopes " in
      *" $vendor_scope "*) ;;
      *) printf '%s\t%s\n' "$skill_name" "$skill_dir" ;;
    esac
  done < <(skill_catalog_vendor_records "$catalog" "$repo_dir")
}
