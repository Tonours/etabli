#!/usr/bin/env bash
# Entry chain stays a map, not a manual: cap its total lines (ADR-0042).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CAP=420
FILES="AGENTS.md workflow/spec.md workflow/agent-rules.md workflow/contract-details.md"

total_lines() {
  local root="$1" total=0 f
  for f in $FILES; do
    total=$((total + $(wc -l <"$root/$f")))
  done
  printf '%s\n' "$total"
}

check_budget() {
  local root="$1" total
  total="$(total_lines "$root")"
  if [ "$total" -gt "$CAP" ]; then
    printf 'entry-chain budget: entry chain is %s lines, %s over the cap of %s (%s)\n' "$total" "$((total - CAP))" "$CAP" "$FILES" >&2
    printf 'Remediation: shrink the chain (move detail to a cold contract), or raise CAP in tests/entry-chain-budget-smoke.sh in the same diff and say why in that run.\n' >&2
    return 1
  fi
}

check_budget "$ROOT_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/workflow"
for f in $FILES; do cp "$ROOT_DIR/$f" "$tmp_dir/$f"; done
over=$((CAP - $(total_lines "$tmp_dir") + 1))
i=0
while [ "$i" -lt "$over" ]; do
  printf 'padding\n' >>"$tmp_dir/workflow/spec.md"
  i=$((i + 1))
done
if check_budget "$tmp_dir" 2>"$tmp_dir/err"; then
  printf 'FAIL: entry-chain budget accepted an over-cap copy\n' >&2
  exit 1
fi
grep -Fq 'Remediation:' "$tmp_dir/err" || {
  printf 'FAIL: entry-chain budget failure lacks a remediation message\n' >&2
  exit 1
}

printf 'PASS: entry-chain budget smoke (%s/%s lines)\n' "$(total_lines "$ROOT_DIR")" "$CAP"
