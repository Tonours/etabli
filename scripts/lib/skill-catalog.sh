#!/usr/bin/env bash

skill_catalog_names() {
  local catalog="$1"
  local source="${2:-any}"
  local flag="${3:-any}"

  awk -F '\t' -v source="$source" -v flag="$flag" '
    $0 !~ /^#/ && NF >= 5 &&
    (source == "any" || $2 == source) &&
    (flag == "any" || (flag == "pi_core" && $3 == "1") ||
      (flag == "codex_visible" && $4 == "1") || (flag == "locked" && $5 == "1")) {
      print $1
    }
  ' "$catalog"
}
