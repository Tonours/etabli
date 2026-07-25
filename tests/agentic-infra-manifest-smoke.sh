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

duplicates="$(awk -F '\t' '!/^#/ && NF {print $3}' "$MANIFEST" | sort | uniq -d)"
[ -z "$duplicates" ] || fail "duplicate labels: $duplicates"

while IFS=$'\t' read -r profile group label target; do
  case "$profile" in core|full|live) ;; *) fail "unknown profile for $label: $profile" ;; esac
  case "$group" in shell-docs|pi|nvim) ;; *) fail "unknown group for $label: $group" ;; esac
  [ -n "$label" ] && [ -n "$target" ] || fail "empty label or target"
  case "$target" in
    builtin:*) ;;
    tests/*.sh) [ -f "$ROOT_DIR/$target" ] || fail "missing target for $label: $target" ;;
    *) fail "unsupported target for $label: $target" ;;
  esac
done < <(sed '/^#/d; /^$/d' "$MANIFEST")

for required in \
  answer-quality-check-smoke \
  obvault-routing-smoke \
  obvault-query-smoke \
  workflow-autonomous-plan-loop-smoke \
  shell-syntax \
  json-config \
  pi-typecheck; do
  awk -F '\t' -v required="$required" '!/^#/ && $3 == required {found=1} END {exit !found}' "$MANIFEST" ||
    fail "required check is absent: $required"
done

awk -F '\t' '!/^#/ && $1 == "core" && $2 == "pi" && $3 == "pi-audit" && $4 == "builtin:pi-audit" {found=1} END {exit !found}' "$MANIFEST" ||
  fail "Pi group must enforce bun audit"

expected_core='shell-syntax
json-config
pi-audit
pi-typecheck
pi-tests
router-eval
router-eval-smoke
agent-scenarios-smoke
vnext-suite-smoke
plan-check-freeze-smoke
dual-runtime-guard-matrix-smoke
codex-organization-smoke
deploy-agent-workflow-smoke
supply-chain-smoke
workflow-contract-coverage-smoke'
actual_core="$(awk -F '\t' '!/^#/ && $1 == "core" {print $3}' "$MANIFEST")"
[ "$actual_core" = "$expected_core" ] || fail "core profile membership/order drifted"
[ "$(printf '%s\n' "$actual_core" | wc -l | tr -d ' ')" -le 15 ] ||
  fail "core profile exceeds 15 checks"

expected_full='pr-latest-head-status-smoke
workflow-efficiency-report-smoke
workflow-monitor-smoke
workflow-metrics-smoke
workflow-telemetry-recover-smoke
workflow-dossier-smoke
workflow-retrospect-smoke
research-proof-check-smoke
answer-quality-check-smoke
answer-quality-eval-smoke
workflow-docs-smoke
workflow-scaffold-smoke
claude-hooks-smoke
claude-skills-smoke
workflow-event-smoke
workflow-autonomous-plan-loop-smoke
project-autonomy-smoke
runtime-capabilities-smoke
adr-hook-smoke
adr-validate-smoke
adr-validation-golden
adr-helper-smoke
validate-adrs
multi-model-quality-score-smoke
browser-full-page-capture-smoke
obvault-routing-smoke
obvault-query-smoke
agentic-infra-manifest-smoke
pi-paths-smoke
skill-lock
pi-import-smoke
fix-links-smoke
install-smoke
nvim-smoke
graph-contract-smoke
graph-neighborhood-smoke
action-graph-smoke
obvault-shadow-promote-smoke
autonomous-ledger-hygiene-smoke'
actual_full="$(awk -F '\t' '!/^#/ && $1 == "full" {print $3}' "$MANIFEST")"
[ "$actual_full" = "$expected_full" ] || fail "full profile membership/order drifted"

expected_live='workflow-cli-smoke
workflow-real-agent-scenarios'
actual_live="$(awk -F '\t' '!/^#/ && $1 == "live" {print $3}' "$MANIFEST")"
[ "$actual_live" = "$expected_live" ] || fail "live profile membership/order drifted"

expected_pi='pi-audit
pi-typecheck
pi-tests
router-eval
skill-lock
pi-import-smoke'
actual_pi="$(awk -F '\t' '!/^#/ && $1 != "live" && $2 == "pi" {print $3}' "$MANIFEST")"
[ "$actual_pi" = "$expected_pi" ] || fail "legacy Pi group membership/order drifted"

expected_nvim='fix-links-smoke
install-smoke
nvim-smoke'
actual_nvim="$(awk -F '\t' '!/^#/ && $1 != "live" && $2 == "nvim" {print $3}' "$MANIFEST")"
[ "$actual_nvim" = "$expected_nvim" ] || fail "legacy Nvim group membership/order drifted"

live_output_file="$(mktemp)"
trap 'rm -f "$live_output_file"' EXIT
set +e
env -u RUN_AGENT_CLI_SMOKE -u RUN_REAL_AGENT_SCENARIOS \
  "$ROOT_DIR/scripts/verify-agentic-infra" live >"$live_output_file" 2>&1
live_status=$?
set -e
[ "$live_status" -eq 3 ] || fail "live without opt-ins must exit 3, got $live_status"
grep -Fq 'SKIP live agent proof' "$live_output_file" ||
  fail "live without opt-ins must report SKIP"
if grep -Eq '^(RUN|PASS) ' "$live_output_file"; then
  fail "live without opt-ins must not run or pass a target"
fi

for group in shell-docs pi nvim; do
  count="$(grep -Fc "scripts/verify-agentic-infra $group" "$WORKFLOW")"
  [ "$count" -eq 1 ] || fail "CI must call canonical group $group exactly once, found $count"
done

shell_docs_job="$(
  awk '
    /^  verify-shell-and-docs:/ { capture = 1 }
    /^  verify-pi-typescript:/ { capture = 0 }
    capture
  ' "$WORKFLOW"
)"
case "$shell_docs_job" in
  *'uses: oven-sh/setup-bun@'*) ;;
  *) fail "shell/docs CI job must install Bun for Bun-backed smoke tests" ;;
esac

if grep -Eq 'run:[[:space:]]+(bash tests/|bun test|node scripts/validate-adrs)' "$WORKFLOW"; then
  fail "CI duplicates a manifest-owned check instead of calling the canonical runner"
fi

printf 'agentic infra manifest smoke test: ok\n'
