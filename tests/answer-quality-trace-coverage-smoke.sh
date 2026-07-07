#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/good" "$TMP_DIR/bad"

cat >"$TMP_DIR/good/audit.md" <<'MD'
Category: audit-handoff
MD
cat >"$TMP_DIR/good/gap.md" <<'MD'
Category: coverage-gap
MD
cat >"$TMP_DIR/good/cross.md" <<'MD'
Category: source-backed-cross-project-handoff
MD
touch "$TMP_DIR/bad/wrong.md"

cat >"$TMP_DIR/good/coverage.tsv" <<'TSV'
category	status	trace	note
audit-handoff	covered	audit.md	Trace exists.
coverage-gap	covered	gap.md	Trace exists.
source-backed-cross-project-handoff	covered	cross.md	Trace exists.
direct-repo-explanation	needs-work	-	Needs real trace.
obvault-backed-memory-answer	needs-work	-	Needs real trace.
blocked-or-inconclusive-answer	needs-work	-	Needs real trace.
large-diff-implementation-handoff	needs-work	-	Needs real trace.
TSV

cat >"$TMP_DIR/bad/coverage.tsv" <<'TSV'
category	status	trace	note
audit-handoff	covered	missing.md	Trace does not exist.
coverage-gap	covered	-	Covered cannot use dash.
source-backed-cross-project-handoff	covered	wrong.md	Trace has no matching category.
TSV

"$ROOT_DIR/scripts/answer-quality-trace-coverage" "$TMP_DIR/good/coverage.tsv" >/dev/null

if "$ROOT_DIR/scripts/answer-quality-trace-coverage" "$TMP_DIR/bad/coverage.tsv" >/dev/null 2>&1; then
  printf 'answer quality trace coverage should fail malformed coverage\n' >&2
  exit 1
fi

printf 'answer quality trace coverage smoke test: ok\n'
