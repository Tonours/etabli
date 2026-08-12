#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CONTRACT="$ROOT_DIR/workflow/skills/recurring-run.md"
SKILL="$ROOT_DIR/pi/skills/recurring-run/SKILL.md"
PATTERNS="$ROOT_DIR/pi/skills/goal-prompt-rewriter/references/patterns.md"
FIXTURES="$ROOT_DIR/tests/fixtures/goal-prompt-rewriter/maintenance-goals.md"

for file in "$CONTRACT" "$SKILL" "$PATTERNS" "$FIXTURES"; do
  [ -f "$file" ] || { printf 'missing recurring/maintenance artifact: %s\n' "$file" >&2; exit 1; }
done

for needle in 'stable run key' 'current source-of-truth' '`no_op`' 'same explicit authority' 'Update recurring-run memory only after validation'; do
  grep -Fq -- "$needle" "$CONTRACT" || { printf 'missing recurring contract clause: %s\n' "$needle" >&2; exit 1; }
done

grep -Fq -- 'workflow/skills/recurring-run.md' "$SKILL"
if grep -Fq -- 'TODO' "$SKILL"; then
  printf 'recurring-run skill still contains TODO guidance\n' >&2
  exit 1
fi

for needle in 'versioned primary release notes' 'Separate direct dependencies from transitive dependencies' 'focused checks' 'full relevant suite' 'review/simplification' 'Never promise that everything will be perfectly current or safe'; do
  grep -Fq -- "$needle" "$PATTERNS" || { printf 'missing maintenance pattern clause: %s\n' "$needle" >&2; exit 1; }
done

if [ "$(grep -c '^/goal ' "$FIXTURES")" -ne 2 ]; then
  printf 'expected exactly two maintenance goal fixtures\n' >&2
  exit 1
fi

for needle in 'direct' 'transitive' 'security' 'migration' 'full' 'review/simplification' 'Stop with' 'Do not deploy'; do
  grep -Fiq -- "$needle" "$FIXTURES" || { printf 'maintenance fixtures miss: %s\n' "$needle" >&2; exit 1; }
done

printf 'recurring run and maintenance goal pattern smoke test: ok\n'
