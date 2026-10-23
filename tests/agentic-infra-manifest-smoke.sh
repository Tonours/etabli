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
	case "$profile" in core | full) ;; *) fail "unknown profile for $label: $profile" ;; esac
	case "$group" in shell-docs | pi) ;; *) fail "unknown group for $label: $group" ;; esac
	[ -n "$label" ] && [ -n "$target" ] || fail "empty label or target"
	case "$target" in
	builtin:*) ;;
	tests/*.sh | tests/*.mjs) [ -f "$ROOT_DIR/$target" ] || fail "missing target for $label: $target" ;;
	*) fail "unsupported target for $label: $target" ;;
	esac
done < <(sed '/^#/d; /^$/d' "$MANIFEST")

for required in \
	shell-syntax \
	json-config \
	pi-typecheck; do
	awk -F '\t' -v required="$required" '!/^#/ && $3 == required {found=1} END {exit !found}' "$MANIFEST" ||
		fail "required check is absent: $required"
done

awk -F '\t' '!/^#/ && $1 == "full" && $2 == "pi" && $3 == "pi-audit" && $4 == "builtin:pi-audit" {found=1} END {exit !found}' "$MANIFEST" ||
	fail "Pi group must enforce bun audit outside the offline core profile"

# The runner must accumulate failures instead of aborting on the first one
# (ADR-0014 lesson); pin the construct so a revert cannot pass silently.
runner_source="$(cat "$ROOT_DIR/scripts/verify-agentic-infra")"
printf '%s\n' "$runner_source" | grep -Fq 'failed=$((failed + 1))' ||
	fail "verify-agentic-infra lost FAIL accumulation"
printf '%s\n' "$runner_source" | grep -Fq 'SUMMARY:' ||
	fail "verify-agentic-infra lost the failure summary"
actual_nvim="$(awk -F '\t' '!/^#/ && $2 == "nvim" {print $3}' "$MANIFEST")"
[ -z "$actual_nvim" ] || fail "Nvim checks belong to dotfiles, not Etabli: $actual_nvim"

stdin_root="$(mktemp -d)"
trap 'rm -rf "$stdin_root"' EXIT

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

[ "$(grep -c '^    timeout-minutes:' "$WORKFLOW")" -eq 2 ] || fail "both CI jobs must set timeout-minutes"
[ "$(grep -c 'uses: actions/cache@' "$WORKFLOW")" -eq 2 ] || fail "both CI jobs must cache bun installs"
grep -Eq '^    branches: \[main\]$' "$WORKFLOW" || fail "CI push runs must be limited to main"
if printf '%s\n' "$(cat "$ROOT_DIR/scripts/verify-agentic-infra")" | grep -Fq 'sysctl'; then
	fail "verify-agentic-infra must count cores with getconf, not the macOS-only sysctl"
fi

if grep -Eq 'run:[[:space:]]+(bash tests/|bun test|node scripts/validate-adrs)' "$WORKFLOW"; then
	fail "CI duplicates a manifest-owned check instead of calling the canonical runner"
fi


# A check that reads stdin must not swallow the remaining manifest rows: run a
# copy of the runner, serialized, with a stdin-eating target first and a red
# target in the middle; every row must still run exactly once.
mkdir -p "$stdin_root/scripts" "$stdin_root/tests" "$stdin_root/workflow/runtime"
cp "$ROOT_DIR/scripts/verify-agentic-infra" "$stdin_root/scripts/verify-agentic-infra"
printf '#!/usr/bin/env bash\ncat >/dev/null\n' >"$stdin_root/tests/eat-stdin.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$stdin_root/tests/ok.sh"
printf '#!/usr/bin/env bash\nexit 1\n' >"$stdin_root/tests/red.sh"
stdin_labels='eat-stdin
red
ok-after-red
ok-last'
printf 'core\tshell-docs\teat-stdin\ttests/eat-stdin.sh\ncore\tshell-docs\tred\ttests/red.sh\ncore\tshell-docs\tok-after-red\ttests/ok.sh\ncore\tshell-docs\tok-last\ttests/ok.sh\n' \
	>"$stdin_root/workflow/runtime/agentic-infra-checks.tsv"
set +e
AGENTIC_INFRA_JOBS=1 "$stdin_root/scripts/verify-agentic-infra" core >"$stdin_root/out" 2>&1
stdin_status=$?
set -e
[ "$stdin_status" -ne 0 ] || fail "a red check must make the runner exit nonzero"
[ "$(awk '/^RUN /{print $2}' "$stdin_root/out")" = "$stdin_labels" ] ||
	fail "every selected check must run exactly once even when one reads stdin (child stdin must be /dev/null)"
grep -Fq 'SUMMARY: 1/4 checks failed: red' "$stdin_root/out" ||
	fail "the summary must count every selected check"

printf '#!/usr/bin/env bash\nkill -TERM "$PPID"\nsleep 5\n' >"$stdin_root/tests/term.sh"
printf 'core\tshell-docs\tterm\ttests/term.sh\ncore\tshell-docs\tok-after-term\ttests/ok.sh\n' \
	>"$stdin_root/workflow/runtime/agentic-infra-checks.tsv"
set +e
AGENTIC_INFRA_JOBS=1 perl -e 'alarm 10; exec @ARGV' "$stdin_root/scripts/verify-agentic-infra" core >"$stdin_root/out" 2>&1
term_status=$?
set -e
[ "$term_status" -ne 142 ] || fail "a TERM-killed check must return its slot instead of hanging the runner"
grep -Fq 'RUN  ok-after-term' "$stdin_root/out" || fail "the check after a TERM-killed one must still run"
grep -Fq 'SUMMARY: 1/2 checks failed: term' "$stdin_root/out" || fail "a TERM-killed check must count as failed"

printf 'agentic infra manifest smoke test: ok\n'
