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
	case "$profile" in core | full | live) ;; *) fail "unknown profile for $label: $profile" ;; esac
	case "$group" in shell-docs | pi) ;; *) fail "unknown group for $label: $group" ;; esac
	[ -n "$label" ] && [ -n "$target" ] || fail "empty label or target"
	case "$target" in
	builtin:*) ;;
	tests/*.sh | tests/*.mjs) [ -f "$ROOT_DIR/$target" ] || fail "missing target for $label: $target" ;;
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

# Core order doubles as launch priority: the runner caps concurrency, so the
# slowest checks must start first (LPT scheduling).
expected_core='pi-tests
deploy-agent-workflow-smoke
workflow-contract-coverage-smoke
plan-cleanup-smoke
agent-scenarios-smoke
pi-typecheck
plan-check-freeze-smoke
pi-audit
shell-syntax
json-config
router-eval
router-eval-smoke
dual-runtime-guard-matrix-smoke
no-progress-mutate-deny-smoke
supply-chain-smoke
skill-lock
jev-judge-smoke
jev-shadow-smoke
harness-trace-retrospect-smoke
review-contract-surface-smoke
worker-recovery-smoke
workflow-context-budget-smoke
guards-active
ledger-check
contract-coherence
ship-order
ref-linter
adapter-sync
rule-registry
router-parity
proof-shadow
skill-hygiene'
# Core budget: 17 checks. Bumped from 16 (2026-08-25) to add
# review-contract-surface-smoke (<50 ms) — the merge gate that must catch
# contract-surface regressions like the CR-B4 union-cap leak.
# Core budget: 18 checks. Bumped from 17 (2026-08-25) to add
# worker-recovery-smoke (~1s, hermetic) — the dirty-tree salvage contract
# behind the autoresearch driver's queue-liveness guarantee.
# Core budget: 19 checks. Bumped from 18 (2026-09-13) to add
# workflow-context-budget-smoke (<1s, hermetic) — the ratchet gate on resident
# instruction context.
# Core budget: 22 checks. The Jev gates and offline trace-retrospect smoke
# protect the semantic surfaces without making provider calls.
# Core budget: 27 checks. T2-T5 added guards-active, ledger-check,
# contract-coherence, ship-order without updating this pin (full was red);
# T6 step 1 adds ref-linter (~3s, hermetic). Exact count from here on.
# T6 step 2 adds adapter-sync (~2s, hermetic).
# T6 step 3 adds rule-registry + router-parity (one smoke file, two labels).
# T6 step 4 adds proof-shadow (node hook fixtures, hermetic gh stub).
# T7 step 2 adds skill-hygiene (DMI flags + native probe; AC2a/AC3/AC4 sections append).
# T7 step 3 appends skill-trigger-eval (frozen recompute + compare) and
# codex-source (hermetic source-measure gate) to full.
actual_core="$(awk -F '\t' '!/^#/ && $1 == "core" {print $3}' "$MANIFEST")"
[ "$actual_core" = "$expected_core" ] || fail "core profile membership/order drifted"
[ "$(printf '%s\n' "$actual_core" | wc -l | tr -d ' ')" -eq 32 ] ||
	fail "core profile must hold exactly 32 checks"

expected_full='pr-latest-head-status-smoke
leap-harness-validation-smoke
ledger-auto-emit-smoke
workflow-receipts-smoke
ledger-selection-performance-smoke
workflow-supersession-smoke
workflow-retrospect-smoke
research-proof-check-smoke
answer-quality-check-smoke
answer-quality-eval-smoke
workflow-docs-smoke
evidence-proof-smoke
program-state-smoke
workflow-scaffold-smoke
claude-hooks-smoke
claude-agents-smoke
claude-commands-smoke
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
browser-full-page-capture-smoke
obvault-routing-smoke
obvault-query-smoke
agentic-infra-manifest-smoke
pi-paths-smoke
pi-review-hunter-smoke
pi-import-smoke
fix-links-smoke
install-smoke
graph-contract-smoke
graph-neighborhood-smoke
action-graph-smoke
obvault-shadow-promote-smoke
autonomous-ledger-hygiene-smoke
workflow-outcome-metric-smoke
claude-outcome-metric-emit-smoke
claude-token-budget-smoke
claude-profile-smoke
claim-evidence-check-smoke
conversation-retrospect-smoke
recurring-run-goal-pattern-smoke
skill-eval-smoke
etabli-harness-eval-smoke
etabli-harness-eval-v2-smoke
session-handoff-smoke
skill-catalog-name-smoke
skill-tree-hash-smoke
sync-vendor-subpath-smoke
claude-skill-load-check-smoke
pi-skill-load-check-smoke
vendor-surface-policy-smoke
vendor-prune-modes-smoke
jev-review-test
review-run-receipt-test
review-evidence-pack-test
jev-review-campaign-test
jev-candidate-corpus-test
typesafe-transport-test
typesafe-architecture-version-test
harness-token-usage-test
jev-efficiency-candidate-test
jev-efficiency-campaign-test
jev-plan-implement-campaign-test
jev-self-improvement-controller-test
skills-lock-coverage-smoke
skill-trigger-eval
codex-source'
actual_full="$(awk -F '\t' '!/^#/ && $1 == "full" {print $3}' "$MANIFEST")"
[ "$actual_full" = "$expected_full" ] || fail "full profile membership/order drifted"

expected_live='workflow-cli-smoke
workflow-real-agent-scenarios
etabli-harness-eval-live'

# The runner must accumulate failures instead of aborting on the first one
# (ADR-0014 lesson); pin the construct so a revert cannot pass silently.
runner_source="$(cat "$ROOT_DIR/scripts/verify-agentic-infra")"
printf '%s\n' "$runner_source" | grep -Fq 'failed=$((failed + 1))' ||
	fail "verify-agentic-infra lost FAIL accumulation"
printf '%s\n' "$runner_source" | grep -Fq 'SUMMARY:' ||
	fail "verify-agentic-infra lost the failure summary"
printf '%s\n' "$runner_source" | grep -Fq 'fix-links-smoke' ||
	fail "verify-agentic-infra must name the repo-mutating checks"
actual_live="$(awk -F '\t' '!/^#/ && $1 == "live" {print $3}' "$MANIFEST")"
[ "$actual_live" = "$expected_live" ] || fail "live profile membership/order drifted"

# Core order doubles as launch priority (slowest first under the runner's
# concurrency cap); the Pi group inherits that order.
expected_pi='pi-tests
pi-typecheck
pi-audit
router-eval
skill-lock
pi-import-smoke'
actual_pi="$(awk -F '\t' '!/^#/ && $1 != "live" && $2 == "pi" {print $3}' "$MANIFEST")"
[ "$actual_pi" = "$expected_pi" ] || fail "legacy Pi group membership/order drifted"

actual_nvim="$(awk -F '\t' '!/^#/ && $1 != "live" && $2 == "nvim" {print $3}' "$MANIFEST")"
[ -z "$actual_nvim" ] || fail "Nvim checks belong to dotfiles, not Etabli: $actual_nvim"

live_output_file="$(mktemp)"
trap 'rm -f "$live_output_file"' EXIT
set +e
env -u RUN_AGENT_CLI_SMOKE -u RUN_REAL_AGENT_SCENARIOS -u RUN_SKILL_RUNTIME_CANARY \
	"$ROOT_DIR/scripts/verify-agentic-infra" live >"$live_output_file" 2>&1
live_status=$?
set -e
[ "$live_status" -eq 3 ] || fail "live without opt-ins must exit 3, got $live_status"
grep -Fq 'SKIP live agent proof' "$live_output_file" ||
	fail "live without opt-ins must report SKIP"
if grep -Eq '^(RUN|PASS) ' "$live_output_file"; then
	fail "live without opt-ins must not run or pass a target"
fi

for group in shell-docs pi; do
	count="$(grep -Fc "scripts/verify-agentic-infra $group" "$WORKFLOW")"
	[ "$count" -eq 1 ] || fail "CI must call canonical group $group exactly once, found $count"
done
if grep -Fq 'scripts/verify-agentic-infra nvim' "$WORKFLOW"; then
	fail "Neovim CI belongs to dotfiles"
fi

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
