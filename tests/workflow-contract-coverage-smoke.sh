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

# The deployment is independent of the reference scan, so it runs in the
# background while the reference index is built and asserted (its ~0.3s of
# per-file spawn overhead would otherwise dominate the smoke's wall clock).
DEPLOY_TARGET="$TMP_DIR/deployed-project"
DEPLOY_LOG="$TMP_DIR/deploy.log"
"$ROOT_DIR/scripts/deploy-workflow" "$DEPLOY_TARGET" >"$DEPLOY_LOG" 2>&1 &
DEPLOY_PID=$!

# One tree pass collects every `workflow/skills/*.md` mention (was: one
# recursive grep per contract — N walks over pi/node_modules dominated the
# core profile wall time). Vendored node_modules trees are skipped: they are
# third-party code, so a mention there must not count as a repo reference
# (this only tightens the check).
REFERENCES_INDEX="$TMP_DIR/contract-references.txt"
grep -Roh --exclude-dir=node_modules -- 'workflow/skills/[A-Za-z0-9._-]*\.md' \
  "$ROOT_DIR/claude" \
  "$ROOT_DIR/skills" \
  "$ROOT_DIR/pi" \
  "$ROOT_DIR/extras" \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/workflow/spec.md" >"$REFERENCES_INDEX" || true
grep -Roh --exclude-dir=adr --exclude-dir=plan -- 'workflow/skills/[A-Za-z0-9._-]*\.md' \
  "$ROOT_DIR/docs" >>"$REFERENCES_INDEX" || true
sort -u "$REFERENCES_INDEX" -o "$REFERENCES_INDEX"

# The contract inventory is built once (sorted filenames); name handling uses
# parameter expansion — per-contract basename/grep forks used to cost more
# wall time than the scan itself once the deployment overlapped it.
CONTRACT_NAMES="$TMP_DIR/contract-names.txt"
EXPECTED_REFS="$TMP_DIR/expected-refs.txt"
: >"$CONTRACT_NAMES"
: >"$EXPECTED_REFS"
while IFS= read -r contract_path; do
  contract_name="${contract_path##*/}"
  printf '%s\n' "$contract_name" >>"$CONTRACT_NAMES"
  printf 'workflow/skills/%s\n' "$contract_name" >>"$EXPECTED_REFS"
done < <(find "$ROOT_DIR/workflow/skills" -maxdepth 1 -type f -name '*.md' -print | sort)

# Every contract must be referenced somewhere in the managed surfaces. One
# comm over two sorted lists (was: one grep -Fxq fork per contract).
unreferenced="$(comm -23 "$EXPECTED_REFS" "$REFERENCES_INDEX")"
if [ -n "$unreferenced" ]; then
  while IFS= read -r missing; do
    printf 'unreferenced workflow contract: %s\n' "$missing" >&2
  done <<<"$unreferenced"
  exit 1
fi

if ! wait "$DEPLOY_PID"; then
  printf 'deploy-workflow failed:\n' >&2
  cat "$DEPLOY_LOG" >&2
  exit 1
fi
while IFS= read -r contract_name; do
  assert_file "$DEPLOY_TARGET/workflow/skills/$contract_name"
done <"$CONTRACT_NAMES"

printf 'workflow contract coverage smoke test: ok\n'
