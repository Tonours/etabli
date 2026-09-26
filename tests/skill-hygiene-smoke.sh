#!/usr/bin/env bash
# Skill-hygiene gate (T7): DMI flags + native expansion probe (AC1) +
# description-shape tripwire (AC2a). AC3 lives in the dedicated load-checks
# and codex-source checks; AC4 is UNCLAIMED (ponytail is macbook-work-only,
# removal needs a user decision) so no scan section exists here.
# TRIPWIRE-GRADE (AC2): the shape regexes below guard format only and are
# gameable by construction; semantic validation is carried by the FULL
# trigger eval (tests/skill-trigger-eval-smoke.sh).
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

claude_scoped() {
  if [ -f "$ROOT_DIR/claude/scopes/work/$1" ]; then
    printf 'claude/scopes/work/%s\n' "$1"
  else
    printf 'claude/scopes/shared/%s\n' "$1"
  fi
}

# Pinned side-effect set: a 6th skill joins via reviewed-diff list edit only.
SIDE_EFFECT="ship plan-implement implement ci-fix linear-ticket-create"

# --- AC1a: flag VALUE on all 10 pinned paths (mirrors load-check:175) ---
DMI_RE='^disable-model-invocation:[ ]*true[ ]*(#.*)?$'
for name in $SIDE_EFFECT; do
  for file in "pi/skills/$name/SKILL.md" "$(claude_scoped "commands/$name.md")"; do
    [ -f "$ROOT_DIR/$file" ] || fail "AC1a: pinned path missing: $file"
    grep -Eq -e "$DMI_RE" "$ROOT_DIR/$file" || fail "AC1a: $file lacks disable-model-invocation: true"
  done
done

# --- AC1b: native probe — hidden from prompt, still expandable ---
"$ROOT_DIR/scripts/pi-dmi-probe" --dir "$ROOT_DIR/pi/skills" \
  --expect-dmi "$(printf '%s' "$SIDE_EFFECT" | tr ' ' ',')" >/dev/null 2>&1 \
  || fail "AC1b: pi-dmi-probe failed on the 5 side-effect skills"

# --- AC1c: probe negative fixture — unflagged skill must fail ---
mkdir -p "$TMP_DIR/skills/naked"
printf -- '---\nname: naked\ndescription: A skill without the flag.\n---\n\n# Naked\n' >"$TMP_DIR/skills/naked/SKILL.md"
if "$ROOT_DIR/scripts/pi-dmi-probe" --dir "$TMP_DIR/skills" --expect-dmi naked >/dev/null 2>&1; then
  fail "AC1c: probe should fail on an unflagged skill"
fi

# --- AC2a: what+when+not-for shape on the 34 T7-rewritten descriptions ---
# Pinned implement scope (plan-time 21/33 counts superseded): 20 pi names +
# 14 claude files. A new shaped description joins via reviewed-diff list
# edit only. Unrewritten legacy descriptions (27 pi, tripwire-nonconforming
# at implement) are out of scope; the trigger eval validates the mixed
# surface semantically (24/24 at implement).
PI_SHAPED="adversary bug-check ci-fix code-quality implement linear-ticket-create linear-work plan-implement plan-loop pr-qa pr-review review sec-pr thermo-nuclear-code-quality-review verify"
CLAUDE_SHAPED="agents/adversary.md commands/adversary.md commands/bug-check.md commands/ci-fix.md commands/implement.md commands/linear-ticket-create.md commands/linear-work.md commands/plan-implement.md commands/plan-loop.md commands/pr-qa.md commands/pr-review.md commands/review.md commands/sec-pr.md commands/verify-workflow.md"
USE_RE='use\b.*(when|for)\b'
NOT_RE='(not|never|except|don'"'"'t|pas pour)\b'
for name in $PI_SHAPED; do
  file="pi/skills/$name/SKILL.md"
  [ -f "$ROOT_DIR/$file" ] || fail "AC2a: pinned path missing: $file"
  desc="$(grep -m1 -e '^description:' "$ROOT_DIR/$file")"
  printf '%s\n' "$desc" | grep -Eq -i -e "$USE_RE" || fail "AC2a: $file lacks use-when/for"
  printf '%s\n' "$desc" | grep -Eq -i -e "$NOT_RE" || fail "AC2a: $file lacks not-for"
done
for sub in $CLAUDE_SHAPED; do
  file="$(claude_scoped "$sub")"
  [ -f "$ROOT_DIR/$file" ] || fail "AC2a: pinned path missing: $file"
  desc="$(grep -m1 -e '^description:' "$ROOT_DIR/$file")"
  printf '%s\n' "$desc" | grep -Eq -i -e "$USE_RE" || fail "AC2a: $file lacks use-when/for"
  printf '%s\n' "$desc" | grep -Eq -i -e "$NOT_RE" || fail "AC2a: $file lacks not-for"
done

printf 'PASS: skill-hygiene smoke (AC1 DMI flags + native probe + AC2a shape tripwire)\n'
