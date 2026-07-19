#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
MANIFEST="$ROOT_DIR/workflow/runtime/agentic-infra-checks.tsv"
WORKFLOW="$ROOT_DIR/.github/workflows/agentic-infra.yml"

fail() {
  printf 'agentic infra manifest: %s\n' "$1" >&2
  exit 1
}

[ -f "$MANIFEST" ] || fail "missing workflow/runtime/agentic-infra-checks.tsv"

duplicates="$(awk -F '\t' '!/^#/ && NF {print $1 "\t" $2}' "$MANIFEST" | sort | uniq -d)"
[ -z "$duplicates" ] || fail "duplicate group/label entries: $duplicates"

while IFS=$'\t' read -r group label target; do
  case "$group" in shell-docs|pi|nvim) ;; *) fail "unknown group for $label: $group" ;; esac
  [ -n "$label" ] && [ -n "$target" ] || fail "empty label or target"
  case "$target" in
    builtin:*) ;;
    tests/*.sh) [ -f "$ROOT_DIR/$target" ] || fail "missing target for $label: $target" ;;
    *) fail "unsupported target for $label: $target" ;;
  esac
done < <(sed '/^#/d; /^$/d' "$MANIFEST")

for required in \
  answer-quality-audit-smoke \
  obvault-routing-smoke \
  obvault-query-smoke \
  workflow-autonomous-plan-loop-smoke \
  shell-syntax \
  json-config \
  pi-typecheck; do
  awk -F '\t' -v required="$required" '!/^#/ && $2 == required {found=1} END {exit !found}' "$MANIFEST" ||
    fail "required check is absent: $required"
done

awk -F '\t' '!/^#/ && $1 == "pi" && $2 == "pi-audit" && $3 == "builtin:pi-audit" {found=1} END {exit !found}' "$MANIFEST" ||
  fail "Pi group must enforce bun audit"

for group in shell-docs pi nvim; do
  count="$(grep -Fc "scripts/verify-agentic-infra $group" "$WORKFLOW")"
  [ "$count" -eq 1 ] || fail "CI must call canonical group $group exactly once, found $count"
done

if grep -Eq 'run:[[:space:]]+(bash tests/|bun test|node scripts/validate-adrs)' "$WORKFLOW"; then
  fail "CI duplicates a manifest-owned check instead of calling the canonical runner"
fi

printf 'agentic infra manifest smoke test: ok\n'
