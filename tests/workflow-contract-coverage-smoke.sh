#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_file() {
  [ -f "$1" ] || {
    printf 'missing file: %s\n' "$1" >&2
    exit 1
  }
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -Fq -- "$needle" "$path" || {
    printf 'expected %s in %s\n' "$needle" "$path" >&2
    exit 1
  }
}

assert_contract_referenced() {
  local contract_name="$1"

  if ! grep -Fxq -- "workflow/skills/$contract_name.md" "$REFERENCES_INDEX"; then
    printf 'unreferenced workflow contract: %s\n' "workflow/skills/$contract_name.md" >&2
    exit 1
  fi
}

# One tree pass collects every `workflow/skills/*.md` mention (was: one
# recursive grep per contract — N walks over pi/node_modules dominated the
# core profile wall time). Vendored node_modules trees are skipped: they are
# third-party code, so a mention there must not count as a repo reference
# (this only tightens the check).
REFERENCES_INDEX="$TMP_DIR/contract-references.txt"
grep -Roh --exclude-dir=node_modules -- 'workflow/skills/[A-Za-z0-9._-]*\.md' \
  "$ROOT_DIR/claude" \
  "$ROOT_DIR/pi" \
  "$ROOT_DIR/docs" \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/workflow/spec.md" >"$REFERENCES_INDEX" || true
sort -u "$REFERENCES_INDEX" -o "$REFERENCES_INDEX"

while IFS= read -r contract_path; do
  contract_name="$(basename "$contract_path" .md)"
  assert_contract_referenced "$contract_name"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' -print | sort)

DEPLOY_TARGET="$TMP_DIR/deployed-project"
"$ROOT_DIR/scripts/deploy-workflow" "$DEPLOY_TARGET" >/dev/null
while IFS= read -r contract_path; do
  # program-orchestration is frozen and deliberately not deployed
  [ "$(basename "$contract_path")" = "program-orchestration.md" ] && continue
  assert_file "$DEPLOY_TARGET/workflow/skills/$(basename "$contract_path")"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' -print | sort)

tmp_ticket_a="$TMP_DIR/ticket-a.md"
tmp_ticket_b="$TMP_DIR/ticket-b.md"
cp "$ROOT_DIR/workflow/ticket-template.md" "$tmp_ticket_a"
cp "$ROOT_DIR/workflow/ticket-template.md" "$tmp_ticket_b"
printf 'negative spot check\n' >>"$tmp_ticket_b"
if cmp -s "$tmp_ticket_a" "$tmp_ticket_b"; then
  printf 'negative duplicate-identity spot check failed to create divergence\n' >&2
  exit 1
fi

printf 'workflow contract coverage smoke test: ok\n'
