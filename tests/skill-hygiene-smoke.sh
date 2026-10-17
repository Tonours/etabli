#!/usr/bin/env bash
# Skill-hygiene gate: workflow skills stay model-invocable and shaped
# descriptions keep their use-when / not-for clauses (format only).
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

skill_file() {
  if [ -f "$ROOT_DIR/skills/work/$1/SKILL.md" ]; then
    printf 'skills/work/%s/SKILL.md\n' "$1"
  else
    printf 'skills/shared/%s/SKILL.md\n' "$1"
  fi
}

# Workflow skills stay model-invocable on both runtimes.
WORKFLOW_SKILLS="plan-implement implement linear-ticket-create"

# --- AC1a: no DMI flag on the workflow skill paths ---
DMI_RE='^disable-model-invocation:[ ]*true[ ]*(#.*)?$'
for name in $WORKFLOW_SKILLS; do
  file="$(skill_file "$name")"
  [ -f "$ROOT_DIR/$file" ] || fail "AC1a: pinned path missing: $file"
  if grep -Eq -e "$DMI_RE" "$ROOT_DIR/$file"; then
    fail "AC1a: $file must stay model-invocable (drop disable-model-invocation)"
  fi
done

# --- AC2a: what+when+not-for shape on the routed workflow descriptions ---
SHAPED="adversary bug-check code-quality implement linear-ticket-create linear-work plan-implement plan-loop review thermo-nuclear-code-quality-review verify-workflow"
USE_RE='use\b.*(when|for)\b'
NOT_RE='(not|never|except|don'"'"'t|pas pour)\b'
check_shape() {
  [ -f "$ROOT_DIR/$1" ] || fail "AC2a: pinned path missing: $1"
  desc="$(grep -m1 -e '^description:' "$ROOT_DIR/$1")"
  printf '%s\n' "$desc" | grep -Eq -i -e "$USE_RE" || fail "AC2a: $1 lacks use-when/for"
  printf '%s\n' "$desc" | grep -Eq -i -e "$NOT_RE" || fail "AC2a: $1 lacks not-for"
}
for name in $SHAPED; do
  check_shape "$(skill_file "$name")"
done
check_shape claude/scopes/shared/agents/adversary.md

printf 'PASS: skill-hygiene smoke\n'
