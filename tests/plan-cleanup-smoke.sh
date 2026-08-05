#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CLEANUP="$ROOT_DIR/scripts/plan-cleanup"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'plan-cleanup smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$CLEANUP" ] || fail "missing executable plan-cleanup"

write_plan() {
  cat >"$TMP_DIR/PLAN.md" <<'PLAN'
# PLAN.md

## Meta
- Status: READY

## Goal

Finish a bounded implementation.
PLAN
}

write_plan
mkdir -p "$TMP_DIR/docs/plan"
hash="$(shasum -a 256 "$TMP_DIR/PLAN.md" | awk '{print $1}')"
cat >"$TMP_DIR/docs/plan/implemented.md" <<EOF
# Implemented: bounded implementation

- Source plan: \`PLAN.md\` — bounded implementation
- Source plan SHA-256: \`$hash\`
- Status: IMPLEMENTED
EOF

output="$(cd "$TMP_DIR" && "$CLEANUP" --archive docs/plan/implemented.md)"
printf '%s\n' "$output" | jq -e '.removed == "PLAN.md" and .archive == "docs/plan/implemented.md"' >/dev/null ||
  fail "valid cleanup did not report its archive"
[ ! -e "$TMP_DIR/PLAN.md" ] || fail "valid cleanup did not remove root PLAN.md"

write_plan
cat >"$TMP_DIR/docs/plan/invalid.md" <<'EOF'
# Implemented: invalid archive

- Source plan: `PLAN.md`
- Status: IMPLEMENTED
EOF
if (cd "$TMP_DIR" && "$CLEANUP" --archive docs/plan/invalid.md >/dev/null 2>&1); then
  fail "cleanup accepted an archive without matching plan hash"
fi
[ -f "$TMP_DIR/PLAN.md" ] || fail "invalid cleanup removed PLAN.md"

if (cd "$TMP_DIR" && "$CLEANUP" --archive ../outside.md >/dev/null 2>&1); then
  fail "cleanup accepted an archive outside docs/plan"
fi
[ -f "$TMP_DIR/PLAN.md" ] || fail "outside archive cleanup removed PLAN.md"

write_plan
discard_output="$(cd "$TMP_DIR" && "$CLEANUP" --discard unrelated-to-request)"
printf '%s\n' "$discard_output" | jq -e '.removed == "PLAN.md" and .mode == "discard" and .reason == "unrelated-to-request"' >/dev/null ||
  fail "discard did not report mode/reason"
[ ! -e "$TMP_DIR/PLAN.md" ] || fail "discard did not remove root PLAN.md"
discard_record="$(printf '%s\n' "$discard_output" | jq -r '.record')"
[ -f "$TMP_DIR/$discard_record" ] || fail "discard did not write record"
grep -q 'Status: DISCARDED' "$TMP_DIR/$discard_record" || fail "discard record missing DISCARDED status"

write_plan
if (cd "$TMP_DIR" && "$CLEANUP" --discard 'Bad Reason' >/dev/null 2>&1); then
  fail "discard accepted a non-slug reason"
fi
[ -f "$TMP_DIR/PLAN.md" ] || fail "invalid discard removed PLAN.md"

printf 'plan-cleanup smoke test: ok\n'
