#!/usr/bin/env bash
# Tranche 4 contract-coherence pins: every AC closes with aligned prose on
# both sides or a mechanical rule + fixtures. This smoke pins the prose side
# (anchored grep, presence + absence) and executes the single-sourced ci-fix
# ledger example. Mechanical pins live in workflow-event-smoke.sh and the
# router bun tests.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
LOOP="$ROOT_DIR/workflow/skills/implementation-loop.md"
ADV="$ROOT_DIR/workflow/skills/adversary.md"
SPEC="$ROOT_DIR/workflow/spec.md"
CIFIX="$ROOT_DIR/workflow/skills/ci-fix.md"
SHIP="$ROOT_DIR/workflow/skills/ship.md"
CORE="$ROOT_DIR/workflow/runtime/workflow-router-core.mjs"

fail() { printf 'contract-coherence: %s\n' "$1" >&2; exit 1; }
assert_contains() { grep -qF "$2" "$1" || fail "missing [$2] in $1"; }
assert_absent() { grep -qF "$2" "$1" && fail "forbidden [$2] in $1" || true; }
# assert_count counts matching LINES (grep -c), not occurrences: every pin
# below has at most one occurrence per line, so line count == occurrence count.
assert_count() { [ "$(grep -cF "$2" "$1")" = "$3" ] || fail "expected $3 [$2] in $1"; }

# AC1 (F1): small never on a plan route; steps 1-7 plan-routes only.
assert_contains "$LOOP" "Steps 1–7 apply to plan routes only"
assert_contains "$LOOP" "outside the plan gate"
assert_contains "$LOOP" "Small tier (no plan): run the surface's own focused checks instead"
# The "(the task, for small)" qualifier must sit at all 3 plan-verb steps
# small borrows (0 recon, 8 implement, 12b simplify rung 1): count-pinned.
assert_count "$LOOP" "(the task, for small)" "3"
assert_contains "$LOOP" "adversary code-diff review (standard/high-risk:"
assert_absent "$LOOP" "product-dogfood.md"
assert_contains "$LOOP" "both N/A for small"
assert_absent "$LOOP" "optional for small"
assert_absent "$ROOT_DIR/scripts/workflow-event" "tier"

# AC2 (F2) docs: quality row in the events table.
assert_contains "$ROOT_DIR/workflow/events.md" "| \`quality_completed\` |"

# AC3 (F5) docs: Claude agent reclassified as same-family sample, pins kept.
AGENT="$ROOT_DIR/claude/scopes/shared/agents/adversary.md"
assert_contains "$AGENT" "same-family sample"
assert_absent "$AGENT" "cross-model"
assert_contains "$AGENT" "model: fable"
assert_contains "$AGENT" "effort: low"
assert_contains "$ADV" "## Cross-harness frontier pool"
assert_contains "$ADV" "exclude the author's family"

# AC4 (F6): no unqualified force-push ban; cross-ref to ci-fix.
[ "$(grep -c "Never force-push" "$SHIP")" = "$(grep -c "Never force-push, except" "$SHIP")" ] \
  || fail "unqualified Never force-push in $SHIP"
assert_count "$SHIP" "Never force-push, except" "1"
assert_contains "$SHIP" "ci-fix.md"

# AC5 (F7): ci-fix ledger procedure + slug convention.
assert_contains "$CIFIX" "## Event Ledger"
assert_contains "$CIFIX" 'Run slug: `ci-fix-<PR number>-r<n>`'
# Single-source: extract the marked example and EXECUTE it in a tmp dir.
TMP_CIFIX="$(mktemp -d "${TMPDIR:-/tmp}/coherence-cifix.XXXXXX")"
trap 'rm -rf "$TMP_CIFIX"' EXIT
sed -n '/ci-fix-ledger-example-begin/,/ci-fix-ledger-example-end/p' "$CIFIX" \
  | grep -v "ci-fix-ledger-example-" > "$TMP_CIFIX/example.sh"
[ -s "$TMP_CIFIX/example.sh" ] || fail "ci-fix example extraction empty"
TMP="$TMP_CIFIX" ROOT="$ROOT_DIR" bash -e "$TMP_CIFIX/example.sh" \
  || fail "ci-fix ledger example failed to execute + validate"

# AC6 (F8): no dead openai-codex route in the router core.
assert_absent "$CORE" "openai-codex"
assert_count "$CORE" "pool frontalier" "2"

# AC7 (F9): verdict canon declared, validator breadth documented.
assert_contains "$ADV" "Plan-mode verdicts are \`READY\` or \`CHALLENGED\`"
assert_contains "$ADV" "historical compatibility"

# AC8 (F10): named-files check owned by plan-adversary + template hints.
assert_contains "$ADV" "named files/areas for risky changes"
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" "Name files/areas"
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "Name files/areas"
assert_absent "$SPEC" "non-trivial"
assert_absent "$ROOT_DIR/workflow/skills/plan-loop.md" "non-trivial"
assert_absent "$ROOT_DIR/workflow/contract-details.md" "non-trivial"

# AC9 (F15): verify interface vs internal id, one spec line.
assert_contains "$SPEC" "internal id \`verify-workflow\`"

# AC10 (independence): same sentence in all 3 policy consumers.
assert_contains "$ADV" "labeled supplement only"
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/adversary.md" "labeled supplement only"
assert_contains "$ROOT_DIR/pi/skills/adversary/SKILL.md" "labeled supplement only"

# AC11 (Review Changes): canonical section in both templates + 3 pointers.
assert_contains "$ROOT_DIR/PLAN_TEMPLATE.md" "## Review Changes"
assert_contains "$ROOT_DIR/PLAN_TEMPLATE_FULL.md" "## Review Changes"
assert_contains "$ADV" "## Review Changes"
assert_contains "$ROOT_DIR/claude/scopes/shared/commands/adversary.md" "Review Changes"
assert_contains "$ROOT_DIR/pi/skills/adversary/SKILL.md" "## Review Changes"

# AC12 (implement/step 1): task/plan correspondence is prose.
assert_contains "$SPEC" "covering the requested task"
assert_contains "$ROOT_DIR/pi/skills/implement/SKILL.md" "must cover the requested task"
assert_contains "$LOOP" "does not cover it"

printf 'contract-coherence: all pins hold\n'
