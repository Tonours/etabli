#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
GATE="$ROOT_DIR/scripts/workflow-context-budget"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'workflow-context-budget smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$GATE" ] || fail "missing executable scripts/workflow-context-budget"

FIXTURE="$TMP_DIR/fixture"
mkdir -p "$FIXTURE/docs"
# Exactly 100 chars, so a ratchet target is a known number: ceil(100 * 1.03) = 103.
printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' >"$FIXTURE/docs/a.md"
printf 'short\n' >"$FIXTURE/docs/b.md"
[ "$(wc -c <"$FIXTURE/docs/a.md" | tr -d ' ')" -eq 100 ] || fail "fixture file must be 100 chars"

write_budget() {
  cat >"$FIXTURE/budget.json" <<EOF
{
  "version": 1,
  "surfaces": {
    "alpha": {
      "files": ["docs/a.md"],
      "ceiling_chars": $1
    },
    "beta": {
      "files": ["docs/b.md"],
      "ceiling_chars": $2
    }
  }
}
EOF
}

# (a) green pass: exit 0, stdout reports ok
write_budget 200 200
out="$("$GATE" --root "$FIXTURE" --budget budget.json)" || fail "green fixture did not exit 0"
case "$out" in
*ok:*) ;;
*) fail "green fixture did not print ok:" ;;
esac

# (b) over ceiling: exit 1, stderr names the surface, the breach, the
# reviewed-growth path, and --ratchet
write_budget 50 200
if err="$("$GATE" --root "$FIXTURE" --budget budget.json 2>&1 >/dev/null)"; then
  fail "over-ceiling fixture did not exit non-zero"
fi
for needle in 'alpha' 'over its ceiling' 'reviewed budget diff' 'ceiling_chars' 'Decision Log' '--ratchet'; do
  case "$err" in
  *"$needle"*) ;;
  *) fail "over-ceiling stderr missing '$needle'" ;;
  esac
done

# (c) missing listed file: exit 1, stderr names the path
write_budget 200 200
cat >"$FIXTURE/budget.json" <<'EOF'
{
  "surfaces": {
    "alpha": {
      "files": ["docs/a.md", "docs/gone.md"],
      "ceiling_chars": 500
    }
  }
}
EOF
if err="$("$GATE" --root "$FIXTURE" --budget budget.json 2>&1 >/dev/null)"; then
  fail "missing-file fixture did not exit non-zero"
fi
case "$err" in
*docs/gone.md*) ;;
*) fail "missing-file stderr did not name docs/gone.md" ;;
esac

# (d) --ratchet lowers a loose ceiling to ceil(chars * 1.03); a ceiling already
# at its ratchet floor (7 = ceil(6 * 1.03) for the 6-char b.md) stays unchanged
write_budget 500 7
"$GATE" --root "$FIXTURE" --budget budget.json --ratchet >/dev/null ||
  fail "--ratchet on a green fixture did not exit 0"
jq -e '.surfaces.alpha.ceiling_chars == 103' "$FIXTURE/budget.json" >/dev/null ||
  fail "--ratchet did not lower ceiling to ceil(100 * 1.03) = 103"
jq -e '.surfaces.beta.ceiling_chars == 7' "$FIXTURE/budget.json" >/dev/null ||
  fail "--ratchet moved a ceiling already at its ratchet floor"

# (e) --ratchet never raises: a ceiling below current chars stays unchanged and
# the check still fails with the reviewed-growth remediation
write_budget 50 200
if ratchet_err="$("$GATE" --root "$FIXTURE" --budget budget.json --ratchet 2>&1 >/dev/null)"; then
  fail "--ratchet on an over-ceiling fixture did not exit non-zero"
fi
for needle in 'reviewed budget diff' 'ceiling_chars' 'Decision Log' 'otherwise finish the trim'; do
  case "$ratchet_err" in
  *"$needle"*) ;;
  *) fail "over-ceiling --ratchet stderr missing '$needle'" ;;
  esac
done
jq -e '.surfaces.alpha.ceiling_chars == 50' "$FIXTURE/budget.json" >/dev/null ||
  fail "--ratchet raised a ceiling below the measured chars"
jq -e '.surfaces.beta.ceiling_chars == 200' "$FIXTURE/budget.json" >/dev/null ||
  fail "--ratchet wrote ceilings from a run with an over-ceiling surface"

# (f) --json shape
write_budget 200 200
"$GATE" --root "$FIXTURE" --budget budget.json --json |
  jq -e '.estimator == "chars/4" and (.surfaces | to_entries | all(.value | has("files") and has("chars") and has("est_tokens") and has("ceiling_chars") and has("headroom") and has("status")))' >/dev/null ||
  fail "--json report did not match the expected shape"

# (g) invalid budget: non repo-relative path is a usage error (exit 2)
cat >"$FIXTURE/budget.json" <<'EOF'
{
  "surfaces": {
    "alpha": {
      "files": ["../outside.md"],
      "ceiling_chars": 500
    }
  }
}
EOF
set +e
"$GATE" --root "$FIXTURE" --budget budget.json >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || fail "non repo-relative path must exit 2, got $status"

# Real repository gate: green at its frozen ceilings, and the hot-route
# surfaces keep exactly the membership the plan assigns them.
"$GATE" >/dev/null || fail "repo context budget gate is not green"

expected_always_on='["AGENTS.md","CLAUDE.md","claude/CLAUDE.md","pi/AGENTS.md","workflow/agent-quick-card.md"]'
expected_plan_loop='["PLAN_TEMPLATE.md","pi/skills/plan-loop/SKILL.md","workflow/skills/plan-loop.md"]'
expected_plan_implement='["PLAN_TEMPLATE.md","pi/skills/plan-implement/SKILL.md","workflow/answer-quality.md","workflow/events.md","workflow/review-rubric.md","workflow/skills/adversary.md","workflow/skills/implementation-loop.md","workflow/skills/plan-loop.md","workflow/skills/review.md","workflow/templates/plan-archive.md","workflow/templates/review-lead.md","workflow/templates/review-logic-hunter.md","workflow/templates/review-spec-hunter.md"]'
"$GATE" --json |
  jq -e --argjson always_on "$expected_always_on" --argjson plan_loop "$expected_plan_loop" --argjson plan_implement "$expected_plan_implement" '
    (.surfaces["always-on"].files | map(.path) | sort) == $always_on and
    (.surfaces["plan-loop"].files | map(.path) | sort) == $plan_loop and
    (.surfaces["plan-implement"].files | map(.path) | sort) == $plan_implement
  ' >/dev/null ||
  fail "always-on/plan-loop/plan-implement surface membership drifted; update workflow/runtime/context-budget.json only via a reviewed change"

printf 'workflow-context-budget smoke test: ok\n'
