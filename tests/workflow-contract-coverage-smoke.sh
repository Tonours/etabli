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
  local reference="workflow/skills/$contract_name.md"

  if grep -Rsl -- "$reference" \
    "$ROOT_DIR/claude" \
    "$ROOT_DIR/pi" \
    "$ROOT_DIR/codex" \
    "$ROOT_DIR/docs" \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/workflow/spec.md" >/dev/null; then
    return 0
  fi

  if grep -F -- "$reference" "$ROOT_DIR/workflow/spec.md" | grep -Fq "shared-only"; then
    return 0
  fi

  printf 'unreferenced workflow contract: %s\n' "$reference" >&2
  exit 1
}

while IFS= read -r contract_path; do
  contract_name="$(basename "$contract_path" .md)"
  assert_contract_referenced "$contract_name"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' -print | sort)

DEPLOY_TARGET="$TMP_DIR/deployed-project"
"$ROOT_DIR/scripts/deploy-workflow" "$DEPLOY_TARGET" >/dev/null
while IFS= read -r contract_path; do
  assert_file "$DEPLOY_TARGET/workflow/skills/$(basename "$contract_path")"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' -print | sort)

actual_codex_workflow_files="$(
  find "$ROOT_DIR/codex/workflow" -maxdepth 1 -type f -exec basename {} \; | sort
)"
expected_codex_workflow_files="$(
  printf '%s\n' dynamic-workflow-triggers.md | sort
)"
if ! diff -u <(printf '%s\n' "$expected_codex_workflow_files") <(printf '%s\n' "$actual_codex_workflow_files"); then
  printf 'unexpected codex/workflow file set\n' >&2
  exit 1
fi

DRY_HOME="$TMP_DIR/codex-dry-home"
"$ROOT_DIR/scripts/deploy-codex" --dry-run --codex-home "$DRY_HOME" >/dev/null
assert_not_exists "$DRY_HOME"

tmp_ticket_a="$TMP_DIR/ticket-a.md"
tmp_ticket_b="$TMP_DIR/ticket-b.md"
cp "$ROOT_DIR/workflow/ticket-template.md" "$tmp_ticket_a"
cp "$ROOT_DIR/workflow/ticket-template.md" "$tmp_ticket_b"
printf 'negative spot check\n' >> "$tmp_ticket_b"
if cmp -s "$tmp_ticket_a" "$tmp_ticket_b"; then
  printf 'negative duplicate-identity spot check failed to create divergence\n' >&2
  exit 1
fi

printf 'workflow contract coverage smoke test: ok\n'
