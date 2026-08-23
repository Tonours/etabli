#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# --- fast pre-checks (<1s): shell syntax ---
for f in scripts/*.sh .auto/measure.sh .auto/checks.sh; do
  [ -f "$f" ] && bash -n "$f"
done

# --- deterministic surface counts (zero-noise primary metric) ---
# vendor/ = tracked upstream skill snapshots (pinned, restorable) — maintained surface
skills_md=$(find workflow/skills pi/skills vendor -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
skill_kb=$(( $(find workflow/skills pi/skills vendor -name '*.md' -print0 2>/dev/null | xargs -0 cat | wc -c) / 1024 ))
vendor_lines=$(find vendor -type f \( -name '*.md' -o -name '*.tsv' -o -name 'UPSTREAM_SHA' \) -print0 | xargs -0 cat | wc -l | tr -d ' ')
ts_lines=$(find pi/extensions -name '*.ts' -not -path '*__tests__*' | xargs cat | wc -l | tr -d ' ')
script_lines=$(find scripts -type f \( -name '*.sh' -o -name '*.mjs' -o -name '*.js' -o -name '*.ts' \) -print0 | xargs -0 cat | wc -l | tr -d ' ')
workflow_lines=$(find workflow -name '*.md' -o -name '*.tsv' | xargs cat | wc -l | tr -d ' ')
surface=$(( workflow_lines + ts_lines + script_lines + vendor_lines ))

# --- efficiency proxy: verify core wall time (runs once, doubles as check) ---
v_start=$(date +%s)
if scripts/verify-agentic-infra core >/tmp/auto-verify.out 2>&1; then verify_ok=1; else verify_ok=0; fi
v_end=$(date +%s)
verify_s=$(( v_end - v_start ))

echo "METRIC surface=$surface"
echo "METRIC skills_md=$skills_md"
echo "METRIC skill_kb=$skill_kb"
echo "METRIC vendor_lines=$vendor_lines"
echo "METRIC ts_lines=$ts_lines"
echo "METRIC script_lines=$script_lines"
echo "METRIC workflow_lines=$workflow_lines"
echo "METRIC verify_s=$verify_s"
echo "METRIC verify_ok=$verify_ok"

if [ "$verify_ok" -ne 1 ]; then
  echo "verify core FAILED:"; tail -30 /tmp/auto-verify.out
  exit 1
fi
