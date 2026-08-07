#!/usr/bin/env bash

skill_catalog_names() {
  local catalog="$1"
  local source="${2:-any}"
  local flag="${3:-any}"

  awk -F '\t' -v source="$source" -v flag="$flag" '
    $0 !~ /^#/ && NF >= 5 &&
    (source == "any" || $2 == source) &&
    (flag == "any" || (flag == "pi_core" && $3 == "1") ||
      (flag == "agents_visible" && $4 == "1") || (flag == "locked" && $5 == "1") ||
      (flag == "cross_harness" && $6 == "1")) {
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
